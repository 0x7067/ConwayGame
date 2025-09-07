import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published var state: GameState?
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var isFinalLocked: Bool = false

    private let service: GameService
    private let boardId: UUID
    private var playTask: Task<Void, Never>?
    private var stepsThisRun: Int = 0

    init(service: GameService, boardId: UUID) {
        self.service = service
        self.boardId = boardId
    }

    func loadCurrent() async {
        switch await service.getCurrentState(boardId: boardId) {
        case .success(let s):
            self.state = s
            self.isFinalLocked = false
        case .failure(let e):
            self.errorMessage = e.localizedDescription
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
        switch await service.jumpToGeneration(boardId: boardId, generation: generation) {
        case .success(let s):
            self.state = s
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
        switch await service.resetBoard(boardId: boardId) {
        case .success(let s):
            self.state = s
            self.pause()
            self.isFinalLocked = false
        case .failure(let e):
            self.errorMessage = e.localizedDescription
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
                if self.stepsThisRun >= UIConstants.maxAutoStepsPerRun {
                    await MainActor.run { self.pause() }
                    break
                }
                try? await Task.sleep(nanoseconds: 150_000_000) // ~6 fps
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
