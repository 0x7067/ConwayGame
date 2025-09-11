import Foundation
import ConwayGameEngine
import FactoryKit

extension Container {
    var gameEngineConfiguration: Factory<GameEngineConfiguration> {
        self { .default }
        .singleton
    }
    
    var gameEngine: Factory<GameEngine> {
        self { ConwayGameEngine(configuration: self.gameEngineConfiguration()) }
    }
    
    var convergenceDetector: Factory<ConvergenceDetector> {
        self { DefaultConvergenceDetector() }
    }
    
    var boardRepository: Factory<BoardRepository> {
        self { CoreDataBoardRepository(container: PersistenceController.shared.container) }
        .singleton
    }
    
    var gameService: Factory<GameService> {
        self { 
            DefaultGameService(
                gameEngine: self.gameEngine(),
                repository: self.boardRepository(),
                convergenceDetector: self.convergenceDetector()
            )
        }
        .cached
    }
    
    var playSpeedConfiguration: Factory<PlaySpeedConfiguration> {
        self { .default }
        .singleton
    }
    
    var themeManager: Factory<ThemeManager> {
        self { ThemeManager(playSpeedConfiguration: self.playSpeedConfiguration()) }
        .singleton
    }
}
