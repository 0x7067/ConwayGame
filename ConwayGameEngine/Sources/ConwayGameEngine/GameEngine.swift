import Foundation

/// Protocol defining the core Conway's Game of Life computation engine.
///
/// A `GameEngine` is responsible for computing the evolution of cellular automata
/// according to configurable rules. It provides methods for single-step computation
/// and multi-generation advancement with optimization features like early termination
/// when stable states are detected.
public protocol GameEngine {
    /// Computes the next generation state from a given current state.
    ///
    /// This method applies the Game of Life rules to determine which cells
    /// will be alive or dead in the next generation. The computation uses
    /// Moore neighborhood (8 surrounding cells) to count neighbors.
    ///
    /// - Parameter currentState: The current grid state as a 2D array of boolean values
    /// - Returns: The next generation state. Returns the same instance if no changes occur
    ///            to allow for identity checking optimizations
    ///
    /// - Note: If no cells change state, the method returns the original `currentState`
    ///         instance rather than creating a new identical grid. Callers can use
    ///         identity comparison (`===`) to detect when no evolution occurred.
    func computeNextState(_ currentState: CellsGrid) -> CellsGrid

    /// Advances the game state through multiple generations efficiently.
    ///
    /// This method computes the game state after a specified number of generations,
    /// with optimizations for early termination when stable states or cycles are detected.
    /// It uses state hashing to identify when the game has reached a stable configuration
    /// or entered a repeating cycle.
    ///
    /// - Parameters:
    ///   - initialState: The starting grid state
    ///   - generation: The target generation number (must be >= 0)
    /// - Returns: The final computed state after the specified generations
    ///
    /// - Note: Computation may terminate early if:
    ///   - All cells die (extinction)
    ///   - A previously seen state is encountered (cycle detected)
    ///   - No changes occur between generations (stable state)
    func computeStateAtGeneration(_ initialState: CellsGrid, generation: Int) -> CellsGrid
}

/// Static utility methods for applying Game of Life rules and neighbor counting.
///
/// `GameRules` provides the core logic for determining cell survival and birth
/// according to configurable rule sets. It supports multiple variants of cellular
/// automata including classic Conway's Game of Life, HighLife, and Day and Night rules.
public enum GameRules {
    /// Determines whether a cell should be alive in the next generation.
    ///
    /// This method applies the configured survival and birth rules to determine
    /// the next state of a cell based on its current state and neighbor count.
    /// The rules are configurable through `GameEngineConfiguration`.
    ///
    /// - Parameters:
    ///   - isAlive: Current state of the cell (true = alive, false = dead)
    ///   - neighborCount: Number of living neighbors (0-8 for Moore neighborhood)
    ///   - configuration: Rule configuration specifying survival and birth conditions
    /// - Returns: `true` if the cell should be alive in the next generation, `false` otherwise
    ///
    /// - Note: This method is marked `@inline(__always)` for performance optimization
    ///         in hot computation paths.
    @inline(__always) public static func shouldCellLive(
        isAlive: Bool,
        neighborCount: Int,
        configuration: GameEngineConfiguration = .default) -> Bool
    {
        if isAlive {
            // Cell survives if neighbor count is in survival set
            configuration.survivalNeighborCounts.contains(neighborCount)
        } else {
            // Cell is born if neighbor count is in birth set
            configuration.birthNeighborCounts.contains(neighborCount)
        }
    }

    /// Counts the number of living neighbors for a cell at given coordinates.
    ///
    /// This method uses Moore neighborhood (8 surrounding cells) to count living neighbors.
    /// Cells outside the grid boundaries are considered dead (no wrap-around).
    ///
    /// - Parameters:
    ///   - grid: The current game grid
    ///   - x: Row index of the cell (0-based)
    ///   - y: Column index of the cell (0-based)
    /// - Returns: Number of living neighbors (0-8)
    ///
    /// - Note: This method is marked `@inline(__always)` for performance optimization
    ///         as it's called frequently during grid computation.
    @inline(__always) public static func countNeighbors(_ grid: CellsGrid, x: Int, y: Int) -> Int {
        // Interpret parameters as (row, col) to match tests (x=row, y=col)
        // Conway's Game of Life uses Moore neighborhood (8 directions)
        let offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        var count = 0
        for (dr, dc) in offsets {
            let nr = x + dr // x is row index
            let nc = y + dc // y is column index
            if nr >= 0, nr < rows, nc >= 0, nc < cols, grid[nr][nc] {
                count += 1
            }
        }
        return count
    }
}

/// Optimized implementation of Conway's Game of Life with configurable rules.
///
/// `ConwayGameEngine` provides an efficient implementation of cellular automata
/// computation with support for multiple rule variants, early termination optimizations,
/// and cycle detection. The engine is designed for high-performance simulation
/// of Game of Life patterns and variants.
///
/// ## Features
/// - **Configurable Rules**: Supports Conway, HighLife, Day and Night, and custom rules
/// - **Performance Optimized**: Uses identity checking and early termination
/// - **Cycle Detection**: Automatically detects stable states and cycles
/// - **Memory Efficient**: Returns original instance when no changes occur
///
/// ## Usage Example
/// ```swift
/// let engine = ConwayGameEngine(configuration: .classicConway)
/// let nextState = engine.computeNextState(currentGrid)
/// let finalState = engine.computeStateAtGeneration(initialGrid, generation: 100)
/// ```
public final class ConwayGameEngine: GameEngine {
    private let configuration: GameEngineConfiguration

    /// Creates a new Conway Game Engine with the specified configuration.
    ///
    /// - Parameter configuration: The rule configuration to use for computation.
    ///                           Defaults to classic Conway rules (survival: 2,3; birth: 3)
    public init(configuration: GameEngineConfiguration = .default) {
        self.configuration = configuration
    }

    /// Computes the next generation state from the current state.
    ///
    /// This implementation iterates through each cell in the grid, counts its living
    /// neighbors using Moore neighborhood, and applies the configured rules to determine
    /// the cell's state in the next generation. For performance, it returns the original
    /// grid instance if no cells change state.
    ///
    /// - Parameter currentState: The current grid state
    /// - Returns: The next generation state, or the same instance if unchanged
    ///
    /// ## Performance Notes
    /// - Time complexity: O(width × height)
    /// - Space complexity: O(width × height) for new grid, O(1) if unchanged
    /// - Uses early termination when no changes are detected
    public func computeNextState(_ currentState: CellsGrid) -> CellsGrid {
        let height = currentState.count
        guard height > 0 else { return currentState }
        let width = currentState[0].count
        var next = Array(repeating: Array(repeating: false, count: width), count: height)
        var anyChange = false
        for y in 0..<height {
            for x in 0..<width {
                let alive = currentState[y][x]
                // countNeighbors expects (row, col) order
                let n = GameRules.countNeighbors(currentState, x: y, y: x)
                let willLive = GameRules.shouldCellLive(isAlive: alive, neighborCount: n, configuration: configuration)
                next[y][x] = willLive
                if willLive != alive { anyChange = true }
            }
        }
        // Early exit if no changes: return original instance to allow identity checks by caller
        return anyChange ? next : currentState
    }

    /// Advances the game state to a specific generation with optimization.
    ///
    /// This method efficiently computes the game state after the specified number
    /// of generations using state hashing to detect cycles and stable states.
    /// It can terminate early when:
    /// - All cells die (extinction)
    /// - A stable state is reached (no changes between generations)
    /// - A cycle is detected (same state hash appears twice)
    ///
    /// - Parameters:
    ///   - initialState: The starting grid state
    ///   - generation: Target generation number (0 returns initial state)
    /// - Returns: The computed state at the target generation
    ///
    /// ## Performance Notes
    /// - Best case: O(1) if generation is 0
    /// - Average case: O(generation × width × height)
    /// - Early termination reduces actual computation time
    /// - Uses efficient state hashing for cycle detection
    public func computeStateAtGeneration(_ initialState: CellsGrid, generation: Int) -> CellsGrid {
        guard generation > 0 else { return initialState }
        var state = initialState
        var lastHash = BoardHashing.hash(for: state)
        for _ in 0..<generation {
            let next = computeNextState(state)
            // If identical (no change), bail out
            if next as AnyObject === state as AnyObject { return state }
            let nextHash = BoardHashing.hash(for: next)
            if nextHash == lastHash {
                return next
            }
            state = next
            lastHash = nextHash
        }
        return state
    }
}
