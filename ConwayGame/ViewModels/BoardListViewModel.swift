import Foundation
import ConwayGameEngine
import FactoryKit

@MainActor
final class BoardListViewModel: ObservableObject {
    @Published var boards: [Board] = []
    @Published var gameError: GameError?
    @Injected(\.gameService) private var service: GameService
    @Injected(\.boardRepository) private var repository: BoardRepository
    @Injected(\.gameEngineConfiguration) private var gameEngineConfiguration

    func load() async {
        do {
            let boards = try await repository.loadAll()
            self.boards = boards.sorted(by: { $0.createdAt > $1.createdAt })
        } catch {
            self.boards = []
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError("Failed to load boards: \(error.localizedDescription)")
            }
        }
    }

    func createRandomBoard(name: String = "Board", width: Int? = nil, height: Int? = nil, density: Double? = nil) async {
        let actualWidth = width ?? gameEngineConfiguration.defaultBoardWidth
        let actualHeight = height ?? gameEngineConfiguration.defaultBoardHeight
        let actualDensity = density ?? gameEngineConfiguration.defaultRandomDensity
        
        var cells = Array(repeating: Array(repeating: false, count: actualWidth), count: actualHeight)
        for y in 0..<actualHeight { for x in 0..<actualWidth { cells[y][x] = Double.random(in: 0...1) < actualDensity } }
        let boardId = await service.createBoard(cells)
        
        // Update the board name if different from default
        if name != "Board-\(boardId.uuidString.prefix(8))" {
            try? await repository.rename(id: boardId, newName: name)
        }
        
        await load()
    }

    func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            await load()
        } catch {
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError("Failed to delete board: \(error.localizedDescription)")
            }
        }
    }
    
    func handleRecoveryAction(_ action: ErrorRecoveryAction) {
        switch action {
        case .retry:
            Task { await load() }
        case .goBack, .goToBoardList, .createNew, .continueWithoutSaving, .cancel, .contactSupport, .resetBoard, .tryAgain:
            break
        }
    }
}

