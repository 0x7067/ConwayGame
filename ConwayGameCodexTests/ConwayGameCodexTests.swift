//
//  ConwayGameCodexTests.swift
//  ConwayGameCodexTests
//
//  Created by Pedro Guimarães on 9/7/25.
//

import XCTest
@testable import ConwayGameCodex

final class ConwayGameCodexTests: XCTestCase {

    func test_blockStillLifeRemainsStable() throws {
        let engine = ConwayGameEngine()
        let grid: CellsGrid = [
            [false,false,false,false],
            [false,true, true, false],
            [false,true, true, false],
            [false,false,false,false],
        ]
        let next = engine.computeNextState(grid)
        XCTAssertEqual(next, grid)
    }

    func test_blinkerOscillatorPeriod2() throws {
        let engine = ConwayGameEngine()
        let grid: CellsGrid = [
            [false,false,false,false,false],
            [false,false,false,false,false],
            [false,true, true, true, false],
            [false,false,false,false,false],
            [false,false,false,false,false],
        ]
        let next = engine.computeNextState(grid)
        let expected: CellsGrid = [
            [false,false,false,false,false],
            [false,false,true, false,false],
            [false,false,true, false,false],
            [false,false,true, false,false],
            [false,false,false,false,false],
        ]
        XCTAssertEqual(next, expected)
        XCTAssertEqual(engine.computeNextState(next), grid)
    }

    func test_gliderMovesDiagonally() throws {
        let engine = ConwayGameEngine()
        // Simple glider in 5x5
        var grid: CellsGrid = [
            [false,false,false,false,false],
            [false,false,true, false,false],
            [false,false,false,true, false],
            [false,true, true, true, false],
            [false,false,false,false,false],
        ]
        // After 4 generations, it should translate by (1,1)
        for _ in 0..<4 { grid = engine.computeNextState(grid) }
        let expected: CellsGrid = [
            [false,false,false,false,false],
            [false,false,false,false,false],
            [false,false,true, false,false],
            [false,false,false,true, false],
            [false,false,true, true, false],
        ]
        XCTAssertEqual(grid, expected)
    }

    func test_extinctionDetection() async throws {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        let grid: CellsGrid = [
            [false,false,false],
            [false,true, false],
            [false,false,false],
        ]
        let id = await service.createBoard(grid)
        let final = await service.getFinalState(boardId: id, maxIterations: 4)
        switch final {
        case .success(let s):
            XCTAssertEqual(s.populationCount, 0)
        case .failure:
            XCTFail("Final state failed")
        }
    }
}
