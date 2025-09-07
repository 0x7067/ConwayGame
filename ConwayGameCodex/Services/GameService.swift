import Foundation
import OSLog

public protocol GameService {
    func createBoard(_ initialState: CellsGrid, name: String) async -> Result<UUID, GameError>
    func getCurrentState(boardId: UUID) async -> Result<GameState, GameError>
    func getNextState(boardId: UUID) async -> Result<GameState, GameError>
    func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError>
    func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError>
    func loadBoards() async -> Result<[Board], GameError>
    func deleteBoard(id: UUID) async -> Result<Void, GameError>
    func renameBoard(id: UUID, newName: String) async -> Result<Void, GameError>
    func jumpToGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError>
    func resetBoard(boardId: UUID) async -> Result<GameState, GameError>
}

public final class DefaultGameService: GameService {
    private let gameEngine: GameEngine
    private let repository: BoardRepository
    private let convergenceDetector: ConvergenceDetector
    private let maxHistory: Int
    private let stateCache = LRUCache<String, CellsGrid>(capacity: 16)

    public init(gameEngine: GameEngine, repository: BoardRepository, convergenceDetector: ConvergenceDetector, maxHistory: Int = 2048) {
        self.gameEngine = gameEngine
        self.repository = repository
        self.convergenceDetector = convergenceDetector
        self.maxHistory = maxHistory
    }

    public func getCurrentState(boardId: UUID) async -> Result<GameState, GameError> {
        do {
            guard let board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            let population = board.cells.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            let gs = GameState(boardId: board.id, generation: board.currentGeneration, cells: board.cells, isStable: false, populationCount: population)
            return .success(gs)
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.persistenceError(String(describing: error)))
        }
    }

    public func createBoard(_ initialState: CellsGrid, name: String) async -> Result<UUID, GameError> {
        do {
            let h = BoardHashing.hash(for: initialState)
            let board = try Board(name: name, width: initialState.first?.count ?? 0, height: initialState.count, cells: initialState, initialCells: initialState, stateHistory: [h])
            try await repository.save(board)
            Logger.service.info("Created board: \(board.id.uuidString)")
            return .success(board.id)
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.persistenceError(String(describing: error)))
        }
    }

    public func getNextState(boardId: UUID) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            let current = board.cells
            let next = gameEngine.computeNextState(current)
            let hash = BoardHashing.hash(for: next)
            var historySet = Set(board.stateHistory)
            let convergence = convergenceDetector.checkConvergence(next, history: historySet)

            // Update board
            board.cells = next
            board.currentGeneration += 1
            if board.stateHistory.count >= maxHistory { board.stateHistory.removeFirst(board.stateHistory.count - maxHistory + 1) }
            board.stateHistory.append(hash)
            try await repository.save(board)

            let population = next.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            let isStable = (next == current) || (convergence == .cyclical(period: 1))
            let state = GameState(boardId: board.id, generation: board.currentGeneration, cells: next, isStable: isStable, populationCount: population)
            return .success(state)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    public func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            let cacheKey = "\(boardId.uuidString)-\(generation)"
            if let cached = await stateCache.get(cacheKey) {
                let population = cached.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
                let gs = GameState(boardId: board.id, generation: generation, cells: cached, isStable: false, populationCount: population)
                return .success(gs)
            }
            if generation <= board.currentGeneration {
                // For simplicity, recompute from initial known history.
                // In future, store checkpoints to backtrack efficiently.
                board.currentGeneration = 0
                if let firstHash = board.stateHistory.first { board.stateHistory = [firstHash] }
            }

            var state = board.cells
            var historyMap: [String: Int] = [:]
            for (idx, h) in board.stateHistory.enumerated() { historyMap[h] = idx }
            var gen = board.currentGeneration
            while gen < generation {
                if Task.isCancelled { return .failure(.computationError("Cancelled")) }
                let next = gameEngine.computeNextState(state)
                let hash = BoardHashing.hash(for: next)
                if let prev = historyMap[hash] {
                    // cycle detected, compute period and fast-forward
                    let period = max(1, (gen + 1) - prev)
                    let remaining = generation - (gen + 1)
                    let skip = remaining % period
                    // fast-forward skip steps
                    var s = next
                    for _ in 0..<skip { s = gameEngine.computeNextState(s) }
                    state = s
                    gen = generation
                    break
                }
                historyMap[hash] = gen + 1
                state = next
                gen += 1
            }
            let population = state.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            let isStable = BoardHashing.hash(for: state) == historyMap.first(where: { $0.value == gen })?.key
            let gs = GameState(boardId: board.id, generation: gen, cells: state, isStable: isStable, populationCount: population)
            await stateCache.set(cacheKey, value: state)
            return .success(gs)
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    public func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            var state = board.cells
            var history = Set(board.stateHistory)
            var gen = board.currentGeneration
            let capped = min(maxIterations, UIConstants.maxFinalIterations)
            for _ in 0..<capped {
                if Task.isCancelled { return .failure(.computationError("Cancelled")) }
                let next = gameEngine.computeNextState(state)
                let hash = BoardHashing.hash(for: next)
                let convergence = convergenceDetector.checkConvergence(next, history: history)
                gen += 1
                history.insert(hash)
                state = next
                if case .continuing = convergence { continue }
                let population = state.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
                let isStable = (convergence == .cyclical(period: 1)) || (next as AnyObject === state as AnyObject)
                let gs = GameState(boardId: board.id, generation: gen, cells: state, isStable: isStable, populationCount: population)
                return .success(gs)
            }
            return .failure(.convergenceTimeout(maxIterations: capped))
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    public func loadBoards() async -> Result<[Board], GameError> {
        do { return .success(try await repository.loadAll()) }
        catch { return .failure(.persistenceError(String(describing: error))) }
    }

    public func deleteBoard(id: UUID) async -> Result<Void, GameError> {
        do { try await repository.delete(id: id); return .success(()) }
        catch { return .failure(.persistenceError(String(describing: error))) }
    }

    public func renameBoard(id: UUID, newName: String) async -> Result<Void, GameError> {
        do {
            guard var board = try await repository.load(id: id) else { return .failure(.boardNotFound(id)) }
            board.name = newName
            try await repository.save(board)
            return .success(())
        } catch let e as GameError { return .failure(e) }
        catch { return .failure(.persistenceError(String(describing: error))) }
    }

    public func jumpToGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError> {
        // Compute state at generation and persist as current so next step continues from here
        switch await getStateAtGeneration(boardId: boardId, generation: min(generation, UIConstants.maxJumpGeneration)) {
        case .failure(let e): return .failure(e)
        case .success(let gs):
            do {
                guard var board = try await repository.load(id: boardId) else { return .failure(.boardNotFound(boardId)) }
                board.cells = gs.cells
                board.currentGeneration = gs.generation
                // Keep minimal history: initial + current hash
                if let first = board.stateHistory.first {
                    board.stateHistory = [first, BoardHashing.hash(for: gs.cells)]
                } else {
                    board.stateHistory = [BoardHashing.hash(for: gs.cells)]
                }
                try await repository.save(board)
                return .success(gs)
            } catch let e as GameError { return .failure(e) }
            catch { return .failure(.persistenceError(String(describing: error))) }
        }
    }

    public func resetBoard(boardId: UUID) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else { return .failure(.boardNotFound(boardId)) }
            board.cells = board.initialCells
            board.currentGeneration = 0
            let h = BoardHashing.hash(for: board.initialCells)
            board.stateHistory = [h]
            try await repository.save(board)
            let population = board.initialCells.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            let gs = GameState(boardId: board.id, generation: 0, cells: board.initialCells, isStable: false, populationCount: population)
            return .success(gs)
        } catch let e as GameError { return .failure(e) }
        catch { return .failure(.persistenceError(String(describing: error))) }
    }
}
