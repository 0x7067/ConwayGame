import Foundation
import Vapor
import ConwayGameEngine

struct PatternsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let patterns = routes.grouped("api", "patterns")
        patterns.get(use: listPatterns)
        patterns.get(":name", use: getPattern)
    }
    
    // GET /api/patterns
    func listPatterns(req: Request) async throws -> PatternListResponse {
        let patterns = Pattern.allCases.map { $0.toPatternInfo() }
        return PatternListResponse(patterns: patterns)
    }
    
    // GET /api/patterns/:name
    func getPattern(req: Request) async throws -> PatternResponse {
        guard let patternName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Pattern name is required")
        }
        
        guard let pattern = Pattern.named(patternName) else {
            let availablePatterns = Pattern.allCases.map(\.rawValue).joined(separator: ", ")
            throw Abort(.notFound, reason: "Pattern '\(patternName)' not found. Available patterns: \(availablePatterns)")
        }
        
        return pattern.toPatternResponse()
    }
}