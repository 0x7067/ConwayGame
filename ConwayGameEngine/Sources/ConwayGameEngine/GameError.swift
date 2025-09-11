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
        case let .boardNotFound(id):
            "Board not found: \(id.uuidString)"
        case let .convergenceTimeout(max):
            "Convergence not reached within \(max) iterations."
        case let .generationLimitExceeded(generations):
            "Game didn't reach a final state after \(generations) generations. There are still living cells."
        case .invalidBoardDimensions:
            "Invalid board dimensions or non-rectangular cells."
        case let .persistenceError(message):
            "Persistence error: \(message)"
        case let .computationError(message):
            "Computation error: \(message)"
        }
    }
}
