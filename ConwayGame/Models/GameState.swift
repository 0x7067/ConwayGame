import Foundation

public struct GameState: Codable, Equatable, Sendable {
    public let boardId: UUID
    public let generation: Int
    public let cells: CellsGrid
    // True when the next state equals current (still life)
    public let isStable: Bool
    public let populationCount: Int
}

