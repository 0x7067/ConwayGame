import ConwayGameEngine
import Foundation
import Vapor

struct RulesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rulesRoutes = routes.grouped("api", "rules")

        rulesRoutes.get(use: listRules)
    }

    // MARK: - List Rules Endpoint

    func listRules(req: Request) async throws -> RulesListResponse {
        let rules = [
            (
                name: "conway",
                displayName: "Conway's Game of Life",
                description: "The classic Conway's Game of Life rules: B3/S23",
                config: GameEngineConfiguration.classicConway),
            (
                name: "highlife",
                displayName: "HighLife",
                description: "HighLife variant: B36/S23 - births on 3 or 6 neighbors",
                config: GameEngineConfiguration.highLife),
            (
                name: "daynight",
                displayName: "Day & Night",
                description: "Day & Night rules: B3678/S34678 - complex behavior",
                config: GameEngineConfiguration.dayAndNight)
        ].map { item in
            RuleInfo(
                name: item.name,
                displayName: item.displayName,
                description: item.description,
                survivalNeighborCounts: item.config.survivalNeighborCounts.sorted(),
                birthNeighborCounts: item.config.birthNeighborCounts.sorted())
        }

        return RulesListResponse(rules: rules)
    }
}
