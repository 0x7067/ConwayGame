import ConwayGameEngine
import Foundation
import Vapor

struct PatternsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let patternsRoutes = routes.grouped("api", "patterns")

        patternsRoutes.get(use: listPatterns)
        patternsRoutes.get(":name", use: getPattern)
    }

    // MARK: - List Patterns Endpoint

    func listPatterns(req: Request) async throws -> PatternListResponse {
        let patterns = Pattern.allCases.map { pattern in
            PatternInfo(
                name: pattern.rawValue,
                displayName: pattern.displayName,
                description: pattern.description,
                category: pattern.category.rawValue,
                width: pattern.cells.gridWidth ?? 0,
                height: pattern.cells.gridHeight)
        }

        return PatternListResponse(patterns: patterns)
    }

    // MARK: - Get Pattern Endpoint

    func getPattern(req: Request) async throws -> PatternResponse {
        guard let patternName = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Pattern name is required")
        }

        // Find pattern by name (case-insensitive)
        guard let pattern = Pattern.named(patternName) else {
            throw Abort(.notFound, reason: "Pattern '\(patternName)' not found")
        }

        return PatternResponse(
            name: pattern.rawValue,
            displayName: pattern.displayName,
            description: pattern.description,
            category: pattern.category.rawValue,
            grid: pattern.cells,
            width: pattern.cells.gridWidth ?? 0,
            height: pattern.cells.gridHeight)
    }
}
