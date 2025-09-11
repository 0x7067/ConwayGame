import Foundation
import Vapor
import ConwayGameEngine

// MARK: - Request Models

struct GameStepRequest: Content {
    let grid: [[Bool]]
    let rules: String?
    
    func toConfiguration() -> GameEngineConfiguration {
        switch rules?.lowercased() {
        case "highlife":
            return .highLife
        case "daynight", "dayandnight":
            return .dayAndNight
        default:
            return .classicConway
        }
    }
}

struct GameSimulationRequest: Content {
    let grid: [[Bool]]
    let generations: Int
    let rules: String?
    let includeHistory: Bool?
    
    func toConfiguration() -> GameEngineConfiguration {
        switch rules?.lowercased() {
        case "highlife":
            return .highLife
        case "daynight", "dayandnight":
            return .dayAndNight
        default:
            return .classicConway
        }
    }
}

struct GameValidationRequest: Content {
    let grid: [[Bool]]
}

// MARK: - Response Models

struct GameStepResponse: Content {
    let grid: [[Bool]]
    let generation: Int
    let population: Int
    let hasChanged: Bool
}

struct GameSimulationResponse: Content {
    let initialGrid: [[Bool]]
    let finalGrid: [[Bool]]
    let generationsRun: Int
    let finalPopulation: Int
    let convergence: ConvergenceResponse
    let history: [GenerationResponse]?
}

struct GenerationResponse: Content {
    let generation: Int
    let grid: [[Bool]]
    let population: Int
}

struct ConvergenceResponse: Content {
    let type: String
    let period: Int?
    let finalGeneration: Int
    
    init(from convergence: ConvergenceType, finalGeneration: Int) {
        self.finalGeneration = finalGeneration
        switch convergence {
        case .continuing:
            self.type = "continuing"
            self.period = nil
        case .extinct:
            self.type = "extinct"
            self.period = nil
        case .cyclical(let period):
            self.type = "cyclical"
            self.period = period
        }
    }
}

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

struct ValidationResponse: Content {
    let isValid: Bool
    let width: Int?
    let height: Int?
    let population: Int?
    let errors: [String]
}

// MARK: - Error Models

struct APIErrorResponse: Content {
    let error: String
    let message: String
    let timestamp: Date
    
    init(error: String, message: String) {
        self.error = error
        self.message = message
        self.timestamp = Date()
    }
}