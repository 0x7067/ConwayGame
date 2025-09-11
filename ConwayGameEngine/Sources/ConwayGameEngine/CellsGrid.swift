import Foundation

public typealias CellsGrid = [[Bool]]

public extension CellsGrid {
    /// Calculate the total population (number of living cells) in the grid
    var population: Int {
        reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
    }

    /// Create an empty grid with specified dimensions
    static func empty(width: Int, height: Int) -> CellsGrid {
        (0..<height).map { _ in
            (0..<width).map { _ in false }
        }
    }

    /// Create a grid from a string representation (useful for patterns)
    static func from(string: String, alive: Character = "*", dead: Character = ".") -> CellsGrid {
        let lines = string.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.map { line in
            line.map { $0 == alive }
        }
    }

    /// Convert grid to string representation for display
    func toString(alive: Character = "*", dead: Character = ".") -> String {
        map { row in
            String(row.map { $0 ? alive : dead })
        }.joined(separator: "\n")
    }
}
