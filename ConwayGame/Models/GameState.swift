import Foundation
import ConwayGameEngine

public struct GameState: Codable, Equatable, Sendable {
    public let boardId: UUID
    public let generation: Int
    public let cells: CellsGrid
    public let isStable: Bool
    public let populationCount: Int
    public let convergedAt: Int?
    public let convergenceType: ConvergenceType?
    
    public init(
        boardId: UUID,
        generation: Int,
        cells: CellsGrid,
        isStable: Bool,
        populationCount: Int,
        convergedAt: Int? = nil,
        convergenceType: ConvergenceType? = nil
    ) {
        self.boardId = boardId
        self.generation = generation
        self.cells = cells
        self.isStable = isStable
        self.populationCount = populationCount
        self.convergedAt = convergedAt
        self.convergenceType = convergenceType
    }
}
