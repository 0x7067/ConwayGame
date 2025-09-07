import Foundation

@MainActor
final class BoardListViewModel: ObservableObject {
    @Published var boards: [Board] = []
    private let service: GameService

    init(service: GameService) {
        self.service = service
    }

    func load() async {
        switch await service.loadBoards() {
        case .success(let boards):
            self.boards = boards.sorted(by: { $0.createdAt < $1.createdAt })
        case .failure:
            self.boards = []
        }
    }

    func createRandomBoard(name: String = "Board", width: Int = 20, height: Int = 20, density: Double = 0.2) async {
        var cells = Array(repeating: Array(repeating: false, count: width), count: height)
        for y in 0..<height { for x in 0..<width { cells[y][x] = Double.random(in: 0...1) < density } }
        let result = await service.createBoard(cells, name: name)
        switch result {
        case .success:
            await load()
        case .failure:
            break
        }
    }

    func delete(id: UUID) async {
        _ = await service.deleteBoard(id: id)
        await load()
    }
}

