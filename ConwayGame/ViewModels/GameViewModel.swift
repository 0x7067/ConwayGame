import Foundation
import ConwayGameEngine
import FactoryKit

@MainActor
final class GameViewModel: ObservableObject {
    @Published var state: GameState?
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var gameError: GameError?
    @Published var isFinalLocked: Bool = false
    @Published var playSpeed: PlaySpeed = .normal
    @Published var boardName: String = ""
    @Published var showGenerationLimitAlert: Bool = false

    @Injected(\.gameService) private var service: GameService
    @Injected(\.boardRepository) private var repository: BoardRepository
    private let boardId: UUID
    @Injected(\.themeManager) private var themeManager: ThemeManager
    private var playTask: Task<Void, Never>?
    private var stepsThisRun: Int = 0
    
    // Configurable for testing, defaults to production value
    var maxAutoStepsPerRun: Int = UIConstants.maxAutoStepsPerRun

    init(boardId: UUID) {
        self.boardId = boardId
        self.playSpeed = themeManager.defaultPlaySpeed
    }

    var currentBoardId: UUID {
        boardId
    }

    func loadCurrent() async {
        do {
            guard let board = try await repository.load(id: boardId) else {
                self.gameError = .boardNotFound(boardId)
                return
            }
            let population = board.cells.population
            self.state = GameState(
                boardId: board.id, 
                generation: board.currentGeneration, 
                cells: board.cells, 
                isStable: false, 
                populationCount: population
            )
            self.boardName = board.name
            self.isFinalLocked = false
        } catch {
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError(error.localizedDescription)
            }
        }
    }

    func step() async {
        guard !isFinalLocked else { return }
        switch await service.getNextState(boardId: boardId) {
        case .success(let s):
            self.state = s
        case .failure(let e):
            self.gameError = e
        }
    }

    func jump(to generation: Int) async {
        isFinalLocked = false
        switch await service.getStateAtGeneration(boardId: boardId, generation: generation) {
        case .success(let s):
            self.state = s
            // Update the board in repository to sync with jumped state
            do {
                guard var board = try await repository.load(id: boardId) else { 
                    self.gameError = .boardNotFound(boardId)
                    return 
                }
                board.cells = s.cells
                board.currentGeneration = s.generation
                board.stateHistory = [BoardHashing.hash(for: s.cells)]
                try await repository.save(board)
            } catch {
                if let gameError = error as? GameError {
                    self.gameError = gameError
                } else {
                    self.gameError = .persistenceError(error.localizedDescription)
                }
            }
        case .failure(let e):
            self.gameError = e
        }
    }

    func finalState(maxIterations: Int) async {
        switch await service.getFinalState(boardId: boardId, maxIterations: maxIterations) {
        case .success(let s):
            self.state = s
            self.pause()
            self.isFinalLocked = true
        case .failure(let e):
            if case .generationLimitExceeded = e {
                self.showGenerationLimitAlert = true
            } else {
                self.gameError = e
            }
        }
    }

    func reset() async {
        do {
            let board = try await repository.reset(id: boardId)
            let population = board.cells.population
            self.state = GameState(
                boardId: board.id, 
                generation: 0, 
                cells: board.cells, 
                isStable: false, 
                populationCount: population
            )
            self.pause()
            self.isFinalLocked = false
        } catch {
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError(error.localizedDescription)
            }
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
                try? await Task.sleep(nanoseconds: self.themeManager.interval(for: self.playSpeed))
            }
        }
    }

    func pause() {
        isPlaying = false
        playTask?.cancel()
        playTask = nil
    }

    func handleRecoveryAction(_ action: ErrorRecoveryAction) {
        switch action {
        case .retry:
            Task { await loadCurrent() }
        case .resetBoard:
            Task { await reset() }
        case .tryAgain:
            Task { await step() }
        case .goBack, .goToBoardList, .createNew, .continueWithoutSaving, .cancel, .contactSupport:
            break
        }
    }
    
    deinit { playTask?.cancel() }
}
