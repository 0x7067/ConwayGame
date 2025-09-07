import XCTest
@testable import ConwayGameCodex

final class GameServiceTests: XCTestCase {
    func test_createAndStepBoard() async throws {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        let grid: CellsGrid = [
            [false,false,false],
            [false,true, true],
            [false,true, true],
        ]
        let create = await service.createBoard(grid, name: "Block")
        guard case .success(let id) = create else { XCTFail("Failed to create"); return }
        let step = await service.getNextState(boardId: id)
        guard case .success(let state) = step else { XCTFail("Failed to step"); return }
        XCTAssertEqual(state.cells, grid) // still life
        XCTAssertTrue(state.isStable)
    }
}
