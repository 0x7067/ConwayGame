import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published var state: GameState?
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var isFinalLocked: Bool = false
    @Published var playSpeed: PlaySpeed = .normal
    @Published var boardName: String = ""

    private let service: GameService
    private let repository: BoardRepository
    private let boardId: UUID
    private let themeManager: ThemeManager
    private var playTask: Task<Void, Never>?
    private var stepsThisRun: Int = 0
    
    // Configurable for testing, defaults to production value
    var maxAutoStepsPerRun: Int = UIConstants.maxAutoStepsPerRun

    init(service: GameService, repository: BoardRepository, boardId: UUID, themeManager: ThemeManager) {
        self.service = service
        self.repository = repository
        self.boardId = boardId
        self.themeManager = themeManager
        self.playSpeed = themeManager.defaultPlaySpeed
    }

    var currentBoardId: UUID {
        boardId
    }

    func loadCurrent() async {
        do {
            guard let board = try await repository.load(id: boardId) else {
                self.errorMessage = "Board not found"
                return
            }
            let population = board.cells.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            self.state = GameState(boardId: board.id, generation: board.currentGeneration, 
                                  cells: board.cells, isStable: false, populationCount: population)
            self.boardName = board.name
            self.isFinalLocked = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func step() async {
        guard !isFinalLocked else { return }
        switch await service.getNextState(boardId: boardId) {
        case .success(let s):
            self.state = s
        case .failure(let e):
            self.errorMessage = e.localizedDescription
        }
    }

    func jump(to generation: Int) async {
        isFinalLocked = false
        switch await service.getStateAtGeneration(boardId: boardId, generation: generation) {
        case .success(let s):
            self.state = s
            // Update the board in repository to sync with jumped state
            do {
                guard var board = try await repository.load(id: boardId) else { return }
                board.cells = s.cells
                board.currentGeneration = s.generation
                board.stateHistory = [BoardHashing.hash(for: s.cells)]
                try await repository.save(board)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        case .failure(let e):
            self.errorMessage = e.localizedDescription
        }
    }

    func finalState(maxIterations: Int) async {
        switch await service.getFinalState(boardId: boardId, maxIterations: maxIterations) {
        case .success(let s):
            self.state = s
            self.pause()
            self.isFinalLocked = true
        case .failure(let e):
            self.errorMessage = e.localizedDescription
        }
    }

    func reset() async {
        do {
            let board = try await repository.reset(id: boardId)
            let population = board.cells.reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
            self.state = GameState(boardId: board.id, generation: 0, 
                                  cells: board.cells, isStable: false, populationCount: population)
            self.pause()
            self.isFinalLocked = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        stepsThisRun = 0
        playTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isPlaying {
                await self.step()
                self.stepsThisRun += 1
                if self.stepsThisRun >= self.maxAutoStepsPerRun {
                    await MainActor.run { self.pause() }
                    break
                }
                // Use the selected play speed interval
                try? await Task.sleep(nanoseconds: self.playSpeed.interval)
            }
        }
    }

    func pause() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }

    deinit { playTask?.cancel() }
}
