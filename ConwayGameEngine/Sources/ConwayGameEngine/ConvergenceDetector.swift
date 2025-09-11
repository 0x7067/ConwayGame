import Foundation

/// Protocol for detecting convergence states in Conway's Game of Life simulations.
///
/// A `ConvergenceDetector` analyzes game states to determine when a simulation
/// has reached a terminal or repeating condition. This enables efficient termination
/// of long-running simulations and provides meaningful feedback about pattern behavior.
///
/// ## Detection Methods
/// - **Extinction**: All cells are dead
/// - **Cycle Detection**: Current state matches a previous state in history
/// - **Still Life**: Special case of cycle with period 1 (no change between generations)
///
/// ## Usage Example
/// ```swift
/// let detector = DefaultConvergenceDetector()
/// var history = Set<String>()
///
/// for generation in 0..<maxIterations {
///     let convergence = detector.checkConvergence(currentState, history: history)
///     if convergence != .continuing {
///         print("Converged at generation \(generation): \(convergence.displayName)")
///         break
///     }
///     history.insert(BoardHashing.hash(for: currentState))
///     currentState = engine.computeNextState(currentState)
/// }
/// ```
public protocol ConvergenceDetector {
    /// Analyzes a game state to determine if convergence has occurred.
    ///
    /// This method checks the current state against historical states to detect
    /// cycles, and examines the current state for extinction conditions.
    ///
    /// - Parameters:
    ///   - state: The current game grid state to analyze
    ///   - history: Set of hash strings representing previously seen states
    /// - Returns: The detected convergence type (.continuing, .extinct, or .cyclical)
    ///
    /// - Note: The caller is responsible for maintaining the history set and
    ///         adding the current state hash after this check if convergence
    ///         hasn't occurred.
    func checkConvergence(_ state: CellsGrid, history: Set<String>) -> ConvergenceType
}

/// Default implementation of convergence detection with optimized algorithms.
///
/// `DefaultConvergenceDetector` provides efficient detection of extinction and
/// cycle conditions using state hashing for O(1) cycle detection and optimized
/// extinction checking that short-circuits on the first living cell found.
///
/// ## Performance Characteristics
/// - **Extinction Check**: O(cells) worst case, O(1) best case with early termination
/// - **Cycle Detection**: O(1) average case using hash set lookup
/// - **Memory Usage**: Minimal - no state storage, relies on caller's history
///
/// ## Limitations
/// - Cannot calculate exact cycle periods without storing additional state information
/// - Relies on caller to maintain consistent state history
/// - Hash collisions (extremely rare) could cause false cycle detection
public final class DefaultConvergenceDetector: ConvergenceDetector {
    /// Creates a new convergence detector instance.
    public init() {}

    /// Checks for convergence conditions using extinction and cycle detection.
    ///
    /// The detection process follows this order for optimal performance:
    /// 1. **Extinction Check**: Scans for any living cells (early termination)
    /// 2. **Cycle Detection**: Compares current state hash against history
    /// 3. **Continuing**: Returns if neither condition is met
    ///
    /// - Parameters:
    ///   - state: Current game grid to analyze
    ///   - history: Set of previously seen state hashes
    /// - Returns: Convergence type indicating the detection result
    ///
    /// ## Implementation Notes
    /// - Uses optimized extinction checking with early termination
    /// - Employs efficient state hashing for cycle detection
    /// - Returns generic cyclical result (period 0) since exact period
    ///   calculation requires additional state tracking
    public func checkConvergence(_ state: CellsGrid, history: Set<String>) -> ConvergenceType {
        // Extinction
        if isExtinct(state) { return .extinct }
        let hash = BoardHashing.hash(for: state)
        if history.contains(hash) {
            // We cannot precisely compute period without index positions; return generic cycle
            return .cyclical(period: 0)
        }
        return .continuing
    }

    /// Efficiently determines if all cells in the grid are dead.
    ///
    /// This method uses early termination to minimize the number of cells
    /// that need to be checked. It returns `false` immediately upon finding
    /// the first living cell, making it very fast for grids with any life remaining.
    ///
    /// - Parameter state: The game grid to check for extinction
    /// - Returns: `true` if all cells are dead, `false` if any cell is alive
    ///
    /// - Note: Marked `@inline(__always)` for performance optimization in hot paths
    @inline(__always) private func isExtinct(_ state: CellsGrid) -> Bool {
        for row in state {
            if row.contains(true) { return false }
        }
        return true
    }
}
