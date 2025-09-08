import Foundation
import OSLog

public protocol GameService {
    func createBoard(_ initialState: CellsGrid) async -> UUID
    func getNextState(boardId: UUID) async -> Result<GameState, GameError>
    func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError>
    func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError>
}

public final class DefaultGameService: GameService {
    private let gameEngine: GameEngine
    private let repository: BoardRepository
    private let convergenceDetector: ConvergenceDetector

    public init(gameEngine: GameEngine, repository: BoardRepository, convergenceDetector: ConvergenceDetector) {
        self.gameEngine = gameEngine
        self.repository = repository
        self.convergenceDetector = convergenceDetector
    }


    public func createBoard(_ initialState: CellsGrid) async -> UUID {
        let id = UUID()
        let h = BoardHashing.hash(for: initialState)
        do {
            let board = try Board(
                id: id,
                name: "Board-\(id.uuidString.prefix(8))",
                width: initialState.first?.count ?? 0,
                height: initialState.count,
                cells: initialState,
                initialCells: initialState,
                stateHistory: [h]
            )
            try await repository.save(board)
            Logger.service.info("Created board: \(board.id.uuidString)")
        } catch {
            Logger.service.error("Failed to create board: \(String(describing: error))")
        }
        return id
    }

    public func getNextState(boardId: UUID) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            // Compute next state
            let next = gameEngine.computeNextState(board.cells)
            
            // Update board state
            board.cells = next
            board.currentGeneration += 1
            board.stateHistory.append(BoardHashing.hash(for: next))
            try await repository.save(board)
            
            // Calculate properties
            let population = next.population
            let isStable = next == gameEngine.computeNextState(next)
            
            let state = GameState(boardId: board.id, generation: board.currentGeneration, cells: next, isStable: isStable, populationCount: population)
            return .success(state)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    public func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError> {
        do {
            guard let board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            // Use gameEngine to compute state at generation
            let state = gameEngine.computeStateAtGeneration(board.initialCells, generation: generation)
            let population = state.population
            
            // Check if stable (state unchanged from previous)
            let prevState = generation > 0 ? gameEngine.computeStateAtGeneration(board.initialCells, generation: generation - 1) : board.initialCells
            let isStable = state == prevState
            
            let gs = GameState(boardId: board.id, generation: generation, cells: state, isStable: isStable, populationCount: population)
            return .success(gs)
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    public func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError> {
        do {
            guard let board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            var state = board.initialCells
            var history = Set<String>()
            
            for generation in 0..<maxIterations {
                if Task.isCancelled { 
                    return .failure(.computationError("Cancelled")) 
                }
                
                let hash = BoardHashing.hash(for: state)
                let convergence = convergenceDetector.checkConvergence(state, history: history)
                
                if convergence != .continuing {
                    let population = state.population
                    let gs = GameState(boardId: board.id, generation: generation, cells: state, isStable: true, populationCount: population)
                    return .success(gs)
                }
                
                history.insert(hash)
                state = gameEngine.computeNextState(state)
            }
            
            return .failure(.convergenceTimeout(maxIterations: maxIterations))
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

}
