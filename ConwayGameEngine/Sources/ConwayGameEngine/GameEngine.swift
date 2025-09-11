import Foundation

public protocol GameEngine {
    func computeNextState(_ currentState: CellsGrid) -> CellsGrid
    func computeStateAtGeneration(_ initialState: CellsGrid, generation: Int) -> CellsGrid
}

public struct GameRules {
    @inline(__always)
    public static func shouldCellLive(isAlive: Bool, neighborCount: Int, configuration: GameEngineConfiguration = .default) -> Bool {
        if isAlive {
            // Cell survives if neighbor count is in survival set
            return configuration.survivalNeighborCounts.contains(neighborCount)
        } else {
            // Cell is born if neighbor count is in birth set
            return configuration.birthNeighborCounts.contains(neighborCount)
        }
    }

    @inline(__always)
    public static func countNeighbors(_ grid: CellsGrid, x: Int, y: Int) -> Int {
        // Interpret parameters as (row, col) to match tests (x=row, y=col)
        // Conway's Game of Life uses Moore neighborhood (8 directions)
        let offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        let rows = grid.count
        let cols = rows > 0 ? grid[0].count : 0
        var count = 0
        for (dr, dc) in offsets {
            let nr = x + dr // x is row index
            let nc = y + dc // y is column index
            if nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] {
                count += 1
            }
        }
        return count
    }
}

public final class ConwayGameEngine: GameEngine {
    private let configuration: GameEngineConfiguration
    
    public init(configuration: GameEngineConfiguration = .default) {
        self.configuration = configuration
    }

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