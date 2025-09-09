import Foundation

public enum GameError: LocalizedError, Equatable, Sendable {
    case boardNotFound(UUID)
    case convergenceTimeout(maxIterations: Int)
    case generationLimitExceeded(Int)
    case invalidBoardDimensions
    case persistenceError(String)
    case computationError(String)

    public var errorDescription: String? {
        switch self {
        case .boardNotFound(let id):
            return "Board not found: \(id.uuidString)"
        case .convergenceTimeout(let max):
            return "Convergence not reached within \(max) iterations."
        case .generationLimitExceeded(let generations):
            return "Game didn't reach a final state after \(generations) generations. There are still living cells."
        case .invalidBoardDimensions:
            return "Invalid board dimensions or non-rectangular cells."
        case .persistenceError(let message):
            return "Persistence error: \(message)"
        case .computationError(let message):
            return "Computation error: \(message)"
        }
    }
}