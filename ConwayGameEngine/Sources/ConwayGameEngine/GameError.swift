import Foundation

/// Comprehensive error types for Conway's Game of Life operations.
///
/// `GameError` provides structured error handling across all game operations
/// including board management, computation, and persistence. All errors conform
/// to `LocalizedError` for consistent user-facing error messages.
///
/// ## Error Categories
/// - **Board Management**: Missing or invalid board references
/// - **Computation**: Simulation limits and computational failures
/// - **Persistence**: Data storage and retrieval failures
/// - **Validation**: Invalid input parameters or board configurations
///
/// ## Usage Example
/// ```swift
/// do {
///     let nextState = try await gameService.getNextState(boardId: id)
/// } catch let error as GameError {
///     switch error {
///     case .boardNotFound(let id):
///         print("Board \(id) was deleted")
///     case .generationLimitExceeded(let gen):
///         print("Stopped after \(gen) generations")
///     default:
///         print("Game error: \(error.localizedDescription)")
///     }
/// }
/// ```
public enum GameError: LocalizedError, Equatable, Sendable {
    /// A requested board could not be found in the repository
    ///
    /// - Parameter UUID: The unique identifier of the missing board
    case boardNotFound(UUID)

    /// Convergence detection timed out without finding a stable state
    ///
    /// - Parameter maxIterations: The maximum number of iterations attempted
    case convergenceTimeout(maxIterations: Int)

    /// Simulation exceeded the generation limit with living cells remaining
    ///
    /// This indicates the pattern may be chaotic or have a very long period.
    /// - Parameter Int: The number of generations that were computed
    case generationLimitExceeded(Int)

    /// Board dimensions are invalid or the grid is not rectangular
    case invalidBoardDimensions

    /// Data persistence operation failed
    ///
    /// - Parameter String: Detailed error message from the persistence layer
    case persistenceError(String)

    /// General computation error occurred during game simulation
    ///
    /// - Parameter String: Detailed error message describing the computation failure
    case computationError(String)

    /// Localized, user-friendly error descriptions.
    ///
    /// Provides human-readable error messages suitable for display in user interfaces.
    /// All messages are in English and include relevant context like IDs and limits.
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
