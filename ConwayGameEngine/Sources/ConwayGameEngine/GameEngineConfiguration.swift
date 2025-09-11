import Foundation

/// Configuration for controlling how frequently generations are displayed during simulation.
///
/// `DisplayFrequency` allows fine-tuning of visualization performance by controlling
/// which generations are shown during long-running simulations. This is particularly
/// useful for CLI output and performance optimization in UI updates.
///
/// ## Usage Example
/// ```swift
/// let frequency = DisplayFrequency(initialGenerations: 20, subsequentInterval: 10)
/// if frequency.shouldDisplay(generation: 25) {
///     // Display this generation
/// }
/// ```
public struct DisplayFrequency: Equatable, Codable {
    /// Number of initial generations to display consecutively from the start
    public let initialGenerations: Int

    /// Interval for displaying generations after the initial period
    public let subsequentInterval: Int

    /// Creates a new display frequency configuration.
    ///
    /// - Parameters:
    ///   - initialGenerations: Number of consecutive generations to show from the start
    ///   - subsequentInterval: After initial period, show every Nth generation
    public init(initialGenerations: Int, subsequentInterval: Int) {
        self.initialGenerations = initialGenerations
        self.subsequentInterval = subsequentInterval
    }

    /// Default display frequency: first 10 generations, then every 5th generation
    public static let `default` = DisplayFrequency(
        initialGenerations: 10,
        subsequentInterval: 5)

    /// Determines whether a specific generation should be displayed.
    ///
    /// - Parameter generation: The generation number to check (0-based)
    /// - Returns: `true` if this generation should be displayed, `false` otherwise
    ///
    /// Generations are displayed if they are within the initial period or
    /// fall on the specified interval after that period.
    public func shouldDisplay(generation: Int) -> Bool {
        generation <= initialGenerations || generation % subsequentInterval == 0
    }
}

/// Comprehensive configuration for Conway's Game of Life engine and related systems.
///
/// `GameEngineConfiguration` centralizes all configurable parameters for the game engine,
/// eliminating magic numbers and ensuring consistency across iOS, CLI, and API platforms.
/// It supports multiple cellular automata rule variants and system-wide defaults.
///
/// ## Supported Rule Variants
/// - **Classic Conway**: Survival on 2-3 neighbors, birth on 3 neighbors
/// - **HighLife**: Conway rules + birth on 6 neighbors (creates replicators)
/// - **Day and Night**: Symmetric rules with survival on 3,4,6,7,8 and birth on 3,6,7,8
/// - **Custom Rules**: Define your own survival and birth neighbor counts
///
/// ## Usage Example
/// ```swift
/// // Use a preset configuration
/// let engine = ConwayGameEngine(configuration: .highLife)
///
/// // Create custom rules
/// let customConfig = GameEngineConfiguration(
///     survivalNeighborCounts: [1, 3, 5],
///     birthNeighborCounts: [3]
/// )
/// ```
public struct GameEngineConfiguration: Equatable, Codable {
    /// Set of neighbor counts that allow a living cell to survive to the next generation
    public let survivalNeighborCounts: Set<Int>

    /// Set of neighbor counts that cause a dead cell to become alive in the next generation
    public let birthNeighborCounts: Set<Int>

    /// Default width for newly created game boards
    public let defaultBoardWidth: Int

    /// Default height for newly created game boards
    public let defaultBoardHeight: Int

    /// Default density for random cell generation (0.0 = all dead, 1.0 = all alive)
    public let defaultRandomDensity: Double

    /// Maximum generations to run for pattern showcases and demonstrations
    public let maxPatternGenerations: Int

    /// Controls how frequently generations are displayed during simulation
    public let displayFrequency: DisplayFrequency

    /// Default page size for paginated board lists and data operations
    public let paginationPageSize: Int

    /// Creates a new game engine configuration.
    ///
    /// - Parameters:
    ///   - survivalNeighborCounts: Neighbor counts for cell survival (default: [2, 3])
    ///   - birthNeighborCounts: Neighbor counts for cell birth (default: [3])
    ///   - defaultBoardWidth: Default board width in cells (default: 20)
    ///   - defaultBoardHeight: Default board height in cells (default: 15)
    ///   - defaultRandomDensity: Random cell density 0.0-1.0 (default: 0.25)
    ///   - maxPatternGenerations: Max generations for patterns (default: 50)
    ///   - displayFrequency: Generation display frequency (default: .default)
    ///   - paginationPageSize: Page size for data pagination (default: 20)
    public init(
        survivalNeighborCounts: Set<Int> = [2, 3],
        birthNeighborCounts: Set<Int> = [3],
        defaultBoardWidth: Int = 20,
        defaultBoardHeight: Int = 15,
        defaultRandomDensity: Double = 0.25,
        maxPatternGenerations: Int = 50,
        displayFrequency: DisplayFrequency = .default,
        paginationPageSize: Int = 20)
    {
        self.survivalNeighborCounts = survivalNeighborCounts
        self.birthNeighborCounts = birthNeighborCounts
        self.defaultBoardWidth = defaultBoardWidth
        self.defaultBoardHeight = defaultBoardHeight
        self.defaultRandomDensity = defaultRandomDensity
        self.maxPatternGenerations = maxPatternGenerations
        self.displayFrequency = displayFrequency
        self.paginationPageSize = paginationPageSize
    }

    /// Default configuration using classic Conway's Game of Life rules
    public static let `default` = GameEngineConfiguration()

    /// Classic Conway's Game of Life rules (B3/S23).
    ///
    /// - Survival: A living cell survives if it has 2 or 3 neighbors
    /// - Birth: A dead cell becomes alive if it has exactly 3 neighbors
    /// - This is the original ruleset defined by John Conway in 1970
    public static let classicConway = GameEngineConfiguration(
        survivalNeighborCounts: [2, 3],
        birthNeighborCounts: [3])

    /// HighLife variant rules (B36/S23).
    ///
    /// Extends Conway's rules with an additional birth condition:
    /// - Survival: A living cell survives if it has 2 or 3 neighbors
    /// - Birth: A dead cell becomes alive if it has 3 or 6 neighbors
    /// - Creates replicators - patterns that create copies of themselves
    public static let highLife = GameEngineConfiguration(
        survivalNeighborCounts: [2, 3],
        birthNeighborCounts: [3, 6])

    /// Day and Night variant rules (B3678/S34678).
    ///
    /// A symmetric ruleset where survival and birth conditions overlap:
    /// - Survival: A living cell survives if it has 3, 4, 6, 7, or 8 neighbors
    /// - Birth: A dead cell becomes alive if it has 3, 6, 7, or 8 neighbors
    /// - Named for creating patterns that invert between "day" and "night" phases
    public static let dayAndNight = GameEngineConfiguration(
        survivalNeighborCounts: [3, 4, 6, 7, 8],
        birthNeighborCounts: [3, 6, 7, 8])
}
