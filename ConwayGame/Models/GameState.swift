import Foundation
import ConwayGameEngine

public struct GameState: Codable, Equatable, Sendable {
    public let boardId: UUID
    public let generation: Int
    public let cells: CellsGrid
    public let isStable: Bool
    public let populationCount: Int
}
