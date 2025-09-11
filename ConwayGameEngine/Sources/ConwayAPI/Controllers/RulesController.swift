import Foundation
import Vapor
import ConwayGameEngine

struct RulesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rules = routes.grouped("api", "rules")
        rules.get(use: listRules)
    }
    
    // GET /api/rules
    func listRules(req: Request) async throws -> RulesListResponse {
        let rules = GameEngineConfiguration.apiConfigurations.map { (name, displayName, description, config) in
            config.toRuleInfo(name: name, displayName: displayName, description: description)
        }
        return RulesListResponse(rules: rules)
    }
}