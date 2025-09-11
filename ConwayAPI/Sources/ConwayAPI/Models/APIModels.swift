import ConwayGameEngine
import Foundation
import Vapor

// MARK: - Health Response

struct HealthResponse: Content {
    let status: String
    let timestamp: Date
    let version: String
}

// MARK: - API Info Response

struct APIInfoResponse: Content {
    let name: String
    let version: String
    let description: String
    let endpoints: [String: String]
    let documentation: String
}

// MARK: - Game Endpoints

struct GameStepRequest: Content {
    let grid: [[Bool]]
    let rules: String?

    init(grid: [[Bool]], rules: String? = nil) {
        self.grid = grid
        self.rules = rules
    }
}

struct GameStepResponse: Content {
    let grid: [[Bool]]
    let generation: Int
    let population: Int
    let hasChanged: Bool
}

struct GameSimulationRequest: Content {
    let grid: [[Bool]]
    let generations: Int
    let rules: String?
    let includeHistory: Bool?

    init(grid: [[Bool]], generations: Int, rules: String? = nil, includeHistory: Bool? = nil) {
        self.grid = grid
        self.generations = generations
        self.rules = rules
        self.includeHistory = includeHistory
    }
}

struct GameSimulationResponse: Content {
    let initialGrid: [[Bool]]
    let finalGrid: [[Bool]]
    let generationsRun: Int
    let finalPopulation: Int
    let convergence: ConvergenceResponse
    let history: [GenerationState]?
}

struct GenerationState: Content {
    let generation: Int
    let grid: [[Bool]]
    let population: Int
}

struct ConvergenceResponse: Content {
    let type: String
    let period: Int?
    let finalGeneration: Int
}

struct GameValidationRequest: Content {
    let grid: [[Bool]]
}

struct ValidationResponse: Content {
    let isValid: Bool
    let width: Int?
    let height: Int?
    let population: Int?
    let errors: [String]
}

// MARK: - Patterns Endpoints

struct PatternListResponse: Content {
    let patterns: [PatternInfo]
}

struct PatternInfo: Content {
    let name: String
    let displayName: String
    let description: String
    let category: String
    let width: Int
    let height: Int
}

struct PatternResponse: Content {
    let name: String
    let displayName: String
    let description: String
    let category: String
    let grid: [[Bool]]
    let width: Int
    let height: Int
}

// MARK: - Rules Endpoints

struct RulesListResponse: Content {
    let rules: [RuleInfo]
}

struct RuleInfo: Content {
    let name: String
    let displayName: String
    let description: String
    let survivalNeighborCounts: [Int]
    let birthNeighborCounts: [Int]
}

// MARK: - Error Response

struct ErrorResponse: Content {
    let error: String
    let message: String
    let timestamp: Date

    init(error: String, message: String) {
        self.error = error
        self.message = message
        self.timestamp = Date()
    }
}

// MARK: - Extensions

extension [[Bool]] {
    var gridWidth: Int? {
        isEmpty ? nil : self[0].count
    }

    var gridHeight: Int {
        count
    }

    var isValidGrid: Bool {
        guard let firstWidth = self.first?.count, firstWidth > 0 else { return false }
        for row in self {
            if row.count != firstWidth { return false }
        }
        return true
    }
}

extension ConvergenceType {
    var responseType: String {
        switch self {
        case .continuing:
            "continuing"
        case .extinct:
            "extinct"
        case .cyclical:
            "cyclical"
        }
    }
}
