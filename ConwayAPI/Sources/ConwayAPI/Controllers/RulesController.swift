import Foundation
import Vapor
import ConwayGameEngine

struct RulesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rulesRoutes = routes.grouped("api", "rules")
        
        rulesRoutes.get(use: listRules)
    }
    
    // MARK: - List Rules Endpoint
    
    func listRules(req: Request) async throws -> RulesListResponse {
        let rules = [
            RuleInfo(
                name: "conway",
                displayName: "Conway's Game of Life",
                description: "The classic Conway's Game of Life rules: B3/S23",
                survivalNeighborCounts: Array(GameEngineConfiguration.classicConway.survivalNeighborCounts),
                birthNeighborCounts: Array(GameEngineConfiguration.classicConway.birthNeighborCounts)
            ),
            RuleInfo(
                name: "highlife",
                displayName: "HighLife",
                description: "HighLife variant: B36/S23 - births on 3 or 6 neighbors",
                survivalNeighborCounts: Array(GameEngineConfiguration.highLife.survivalNeighborCounts),
                birthNeighborCounts: Array(GameEngineConfiguration.highLife.birthNeighborCounts)
            ),
            RuleInfo(
                name: "daynight",
                displayName: "Day & Night",
                description: "Day & Night rules: B3678/S34678 - complex behavior",
                survivalNeighborCounts: Array(GameEngineConfiguration.dayAndNight.survivalNeighborCounts),
                birthNeighborCounts: Array(GameEngineConfiguration.dayAndNight.birthNeighborCounts)
            )
        ]
        
        return RulesListResponse(rules: rules)
    }
}