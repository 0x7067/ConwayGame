import Foundation
import ConwayGameEngine

/// Represents a Conway's Game of Life board with persistent state and history tracking.
///
/// `Board` is the core data model for game instances, containing both current and initial
/// states, metadata, and state history for convergence detection. It provides validation
/// to ensure data integrity and supports both persistence and in-memory operations.
///
/// ## Key Features
/// - **State Management**: Tracks current and initial cell configurations
/// - **History Tracking**: Maintains state hashes for cycle detection
/// - **Validation**: Ensures rectangular grids within reasonable size limits
/// - **Metadata**: Includes creation time, naming, and generation counting
/// - **Thread Safety**: Sendable for safe concurrent access
///
/// ## Usage Example
/// ```swift
/// let board = try Board(
///     name: "Glider Pattern",
///     width: 10,
///     height: 10,
///     cells: gliderPattern
/// )
/// 
/// // Advance the simulation
/// board.currentGeneration += 1
/// board.cells = nextGenerationState
/// board.stateHistory.append(stateHash)
/// ```
public struct Board: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for the board, used for persistence and references
    public let id: UUID
    
    /// Human-readable display name for the board
    public var name: String
    
    /// Width of the game grid in cells
    public var width: Int
    
    /// Height of the game grid in cells
    public var height: Int
    
    /// Timestamp when the board was created
    public var createdAt: Date
    
    /// Current generation number (0 = initial state)
    public var currentGeneration: Int
    
    /// Current state of all cells in the grid
    public var cells: CellsGrid
    
    /// Original starting configuration (immutable reference)
    public var initialCells: CellsGrid
    
    /// Whether the board is currently active/enabled
    public var isActive: Bool
    
    /// Array of state hashes for convergence and cycle detection
    ///
    /// Each entry represents a unique board state hash, used to detect
    /// when the simulation has entered a repeating cycle or reached stability.
    public var stateHistory: [String]

    /// Creates a new board with validation of dimensions and grid consistency.
    ///
    /// The initializer validates that dimensions are positive, within limits (1000x1000),
    /// and that the provided cell grid matches the specified dimensions.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - name: Display name for the board
    ///   - width: Grid width in cells (1-1000)
    ///   - height: Grid height in cells (1-1000)
    ///   - createdAt: Creation timestamp (defaults to current time)
    ///   - currentGeneration: Starting generation number (defaults to 0)
    ///   - cells: Current cell grid configuration
    ///   - initialCells: Starting cell configuration (defaults to cells if nil)
    ///   - isActive: Whether board is active (defaults to true)
    ///   - stateHistory: Array of state hashes (defaults to empty)
    /// - Throws: GameError.invalidBoardDimensions if validation fails
    public init(
        id: UUID = UUID(),
        name: String,
        width: Int,
        height: Int,
        createdAt: Date = Date(),
        currentGeneration: Int = 0,
        cells: CellsGrid,
        initialCells: CellsGrid? = nil,
        isActive: Bool = true,
        stateHistory: [String] = []
    ) throws {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.currentGeneration = currentGeneration
        self.cells = cells
        self.initialCells = initialCells ?? cells
        self.isActive = isActive
        self.stateHistory = stateHistory
        try validate()
    }

    /// Validates board dimensions and grid consistency.
    ///
    /// Ensures that:
    /// - Width and height are positive
    /// - Dimensions don't exceed maximum limits (1000x1000)
    /// - Cell grid has exactly `height` rows
    /// - Each row has exactly `width` columns
    ///
    /// - Throws: GameError.invalidBoardDimensions if any validation fails
    public func validate() throws {
        guard width > 0, height > 0, width <= 1000, height <= 1000 else {
            throw GameError.invalidBoardDimensions
        }
        guard cells.count == height, cells.allSatisfy({ $0.count == width }) else {
            throw GameError.invalidBoardDimensions
        }
    }
}
