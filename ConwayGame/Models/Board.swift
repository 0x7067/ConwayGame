import Foundation
import ConwayGameEngine

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
