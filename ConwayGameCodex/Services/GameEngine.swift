import Foundation

public protocol GameEngine {
    func computeNextState(_ currentState: CellsGrid) -> CellsGrid
    func computeStateAtGeneration(_ initialState: CellsGrid, generation: Int) -> CellsGrid
}

public struct GameRules {
    @inline(__always)
    public static func shouldCellLive(isAlive: Bool, neighborCount: Int) -> Bool {
        if isAlive {
            // Survival if 2 or 3 neighbors
            return neighborCount == 2 || neighborCount == 3
        } else {
            // Birth if exactly 3 neighbors
            return neighborCount == 3
        }
    }

    @inline(__always)
    public static func countNeighbors(_ grid: CellsGrid, x: Int, y: Int) -> Int {
        // Finite grid, no wrapping
        let h = grid.count
        let w = h > 0 ? grid[0].count : 0
        var count = 0
        let y0 = max(0, y - 1)
        let y1 = min(h - 1, y + 1)
        let x0 = max(0, x - 1)
        let x1 = min(w - 1, x + 1)
        for j in y0...y1 {
            for i in x0...x1 {
                if i == x && j == y { continue }
                if grid[j][i] { count += 1 }
            }
        }
        return count
    }
}

public final class ConwayGameEngine: GameEngine {
    public init() {}

    public func computeNextState(_ currentState: CellsGrid) -> CellsGrid {
        let height = currentState.count
        guard height > 0 else { return currentState }
        let width = currentState[0].count
        var next = Array(repeating: Array(repeating: false, count: width), count: height)
        var anyChange = false
        for y in 0..<height {
            for x in 0..<width {
                let alive = currentState[y][x]
                let n = GameRules.countNeighbors(currentState, x: x, y: y)
                let willLive = GameRules.shouldCellLive(isAlive: alive, neighborCount: n)
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

