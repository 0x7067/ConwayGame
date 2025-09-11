import Foundation
import ConwayGameEngine

/// Represents the computed state of a Conway's Game of Life board at a specific generation.
///
/// `GameState` provides a snapshot of a board's condition at a particular point in time,
/// including the cell configuration, population statistics, stability analysis, and
/// convergence information. It serves as the primary data structure for simulation results.
///
/// ## Key Properties
/// - **Cell Configuration**: Complete grid state at the target generation
/// - **Population Metrics**: Count of living cells for analysis
/// - **Stability Analysis**: Whether the state will change in the next generation
/// - **Convergence Data**: Information about final states and termination conditions
///
/// ## Usage Scenarios
/// - Displaying simulation results in UI
/// - Analyzing pattern behavior and evolution
/// - Determining simulation termination conditions
/// - Caching computed states for performance
///
/// ## Usage Example
/// ```swift
/// let state = GameState(
///     boardId: board.id,
///     generation: 42,
///     cells: computedGrid,
///     isStable: false,
///     populationCount: 15
/// )
/// 
/// if let convergence = state.convergenceType {
///     print("Converged at generation \(state.convergedAt!): \(convergence.displayName)")
/// }
/// ```
public struct GameState: Codable, Equatable, Sendable {
    /// The unique identifier of the board this state belongs to
    public let boardId: UUID
    
    /// The generation number this state represents (0-based)
    public let generation: Int
    
    /// The complete cell grid configuration at this generation
    public let cells: CellsGrid
    
    /// Whether this state is stable (won't change in the next generation)
    ///
    /// `true` indicates the pattern will remain unchanged if advanced one more generation.
    /// This includes both still lifes and states where all cells are dead.
    public let isStable: Bool
    
    /// The number of living cells in this state
    ///
    /// Used for population analysis, extinction detection, and pattern metrics.
    /// A count of 0 indicates complete extinction.
    public let populationCount: Int
    
    /// The generation where convergence was detected, if applicable
    ///
    /// This property is set when the state represents a final convergent state
    /// (extinction, stable pattern, or detected cycle). It indicates the exact
    /// generation where the convergence condition was first met.
    public let convergedAt: Int?
    
    /// The type of convergence detected, if applicable
    ///
    /// Specifies whether the simulation reached extinction, entered a cycle,
    /// or achieved a stable state. This is only set for terminal states
    /// returned by convergence analysis methods.
    public let convergenceType: ConvergenceType?
    
    /// Creates a new game state with the specified properties.
    ///
    /// - Parameters:
    ///   - boardId: UUID of the associated board
    ///   - generation: Generation number (0-based)
    ///   - cells: Cell grid configuration
    ///   - isStable: Whether state is stable
    ///   - populationCount: Number of living cells
    ///   - convergedAt: Generation where convergence occurred (optional)
    ///   - convergenceType: Type of convergence detected (optional)
    public init(
        boardId: UUID,
        generation: Int,
        cells: CellsGrid,
        isStable: Bool,
        populationCount: Int,
        convergedAt: Int? = nil,
        convergenceType: ConvergenceType? = nil
    ) {
        self.boardId = boardId
        self.generation = generation
        self.cells = cells
        self.isStable = isStable
        self.populationCount = populationCount
        self.convergedAt = convergedAt
        self.convergenceType = convergenceType
    }
}
