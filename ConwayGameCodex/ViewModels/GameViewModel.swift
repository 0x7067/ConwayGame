import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    @Published var state: GameState?
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?

    private let service: GameService
    private let boardId: UUID
    private var playTask: Task<Void, Never>?

    init(service: GameService, boardId: UUID) {
        self.service = service
        self.boardId = boardId
    }

    func step() async {
        switch await service.getNextState(boardId: boardId) {
        case .success(let s):
            self.state = s
        case .failure(let e):
            self.errorMessage = e.localizedDescription
        }
    }

    func jump(to generation: Int) async {
        switch await service.getStateAtGeneration(boardId: boardId, generation: generation) {
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
        case .failure(let e):
            self.errorMessage = e.localizedDescription
        }
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        playTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isPlaying {
                await self.step()
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
