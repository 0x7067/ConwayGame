import Foundation

final class ServiceContainer {
    static let shared = ServiceContainer()

    let gameService: GameService
    let boardRepository: BoardRepository

    private init() {
        let engine = ConwayGameEngine()
        let detector = DefaultConvergenceDetector()
        let repo = CoreDataBoardRepository(container: PersistenceController.shared.container)
        self.boardRepository = repo
        self.gameService = DefaultGameService(gameEngine: engine, repository: repo, convergenceDetector: detector)
    }
}
