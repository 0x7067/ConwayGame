import Foundation

public typealias CellsGrid = [[Bool]]

public struct Board: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var width: Int
    public var height: Int
    public var createdAt: Date
    public var currentGeneration: Int
    public var cells: CellsGrid
    public var initialCells: CellsGrid
    public var isActive: Bool
    // State hashes for convergence/cycle detection
    public var stateHistory: [String]

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

    public func validate() throws {
        guard width > 0, height > 0, width <= 1000, height <= 1000 else {
            throw GameError.invalidBoardDimensions
        }
        guard cells.count == height, cells.allSatisfy({ $0.count == width }) else {
            throw GameError.invalidBoardDimensions
        }
    }
}

public enum ConvergenceType: Codable, Equatable, Sendable {
    case continuing
    case extinct
    case cyclical(period: Int)
}

// MARK: - CellsGrid Extensions
public extension CellsGrid {
    /// Calculate the total population (number of living cells) in the grid
    var population: Int {
        reduce(0) { $0 + $1.reduce(0) { $0 + ($1 ? 1 : 0) } }
    }
}

public enum BoardHashing: Sendable {
    // Convert grid to compact string hash (bit-packed then base64)
    public static func hash(for cells: CellsGrid) -> String {
        let height = cells.count
        let width = height > 0 ? cells[0].count : 0
        if width == 0 || height == 0 { return "" }
        let bitCount = width * height
        var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
        var bitIndex = 0
        for row in 0..<height {
            for col in 0..<width {
                if cells[row][col] {
                    let byteIndex = bitIndex / 8
                    let bitInByte = UInt8(7 - (bitIndex % 8))
                    bytes[byteIndex] |= (1 << bitInByte)
                }
                bitIndex += 1
            }
        }
        return Data(bytes).base64EncodedString()
    }
}
