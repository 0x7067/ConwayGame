import Foundation
import ConwayGameEngine

final class ServiceContainer {
    static let shared = ServiceContainer()

    let gameService: GameService
    let boardRepository: BoardRepository
    let themeManager: ThemeManager
    let gameEngineConfiguration: GameEngineConfiguration
    let playSpeedConfiguration: PlaySpeedConfiguration

    private init() {
        self.gameEngineConfiguration = .default
        self.playSpeedConfiguration = .default
        
        let engine = ConwayGameEngine(configuration: gameEngineConfiguration)
        let detector = DefaultConvergenceDetector()
        let repo = CoreDataBoardRepository(container: PersistenceController.shared.container)
        self.boardRepository = repo
        self.gameService = DefaultGameService(gameEngine: engine, repository: repo, convergenceDetector: detector)
        self.themeManager = ThemeManager(playSpeedConfiguration: playSpeedConfiguration)
    }
}
