import Foundation

@MainActor
final class BoardListViewModel: ObservableObject {
    @Published var boards: [Board] = []
    private let service: GameService
    private let repository: BoardRepository

    init(service: GameService, repository: BoardRepository) {
        self.service = service
        self.repository = repository
    }

    func load() async {
        do {
            let boards = try await repository.loadAll()
            self.boards = boards.sorted(by: { $0.createdAt < $1.createdAt })
        } catch {
            self.boards = []
        }
    }

    func createRandomBoard(name: String = "Board", width: Int = 20, height: Int = 20, density: Double = 0.2) async {
        var cells = Array(repeating: Array(repeating: false, count: width), count: height)
        for y in 0..<height { for x in 0..<width { cells[y][x] = Double.random(in: 0...1) < density } }
        let boardId = await service.createBoard(cells)
        
        // Update the board name if different from default
        if name != "Board-\(boardId.uuidString.prefix(8))" {
            try? await repository.rename(id: boardId, newName: name)
        }
        
        await load()
    }

    func delete(id: UUID) async {
        try? await repository.delete(id: id)
        await load()
    }
}

