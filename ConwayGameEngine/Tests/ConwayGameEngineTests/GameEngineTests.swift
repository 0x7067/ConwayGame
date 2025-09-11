@testable import ConwayGameEngine
import XCTest

final class GameEngineTests: XCTestCase {
    private var engine: ConwayGameEngine!

    override func setUp() {
        super.setUp()
        engine = ConwayGameEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Edge Cases

    func test_emptyGrid_remainsEmpty() {
        let grid: CellsGrid = []
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, grid)
    }

    func test_singleDeadCell_remainsDead() {
        let grid: CellsGrid = [[false]]
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, grid)
    }

    func test_singleLiveCell_dies() {
        let grid: CellsGrid = [[true]]
        let expected: CellsGrid = [[false]]
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, expected)
    }

    // MARK: - Still Lifes

    func test_block_remainsStable() {
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true, true, false],
            [false, true, true, false],
            [false, false, false, false]
        ]
        let result = engine.computeNextState(block)
        XCTAssertEqual(result, block)
    }

    func test_beehive_remainsStable() {
        let beehive: CellsGrid = [
            [false, false, false, false, false, false],
            [false, false, true, true, false, false],
            [false, true, false, false, true, false],
            [false, false, true, true, false, false],
            [false, false, false, false, false, false]
        ]
        let result = engine.computeNextState(beehive)
        XCTAssertEqual(result, beehive)
    }

    func test_loaf_remainsStable() {
        let loaf: CellsGrid = [
            [false, false, false, false, false, false],
            [false, false, true, true, false, false],
            [false, true, false, false, true, false],
            [false, false, true, false, true, false],
            [false, false, false, true, false, false],
            [false, false, false, false, false, false]
        ]
        let result = engine.computeNextState(loaf)
        XCTAssertEqual(result, loaf)
    }

    func test_boat_remainsStable() {
        let boat: CellsGrid = [
            [false, false, false, false, false],
            [false, true, true, false, false],
            [false, true, false, true, false],
            [false, false, true, false, false],
            [false, false, false, false, false]
        ]
        let result = engine.computeNextState(boat)
        XCTAssertEqual(result, boat)
    }

    func test_tub_remainsStable() {
        let tub: CellsGrid = [
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, true, false, true, false],
            [false, false, true, false, false],
            [false, false, false, false, false]
        ]
        let result = engine.computeNextState(tub)
        XCTAssertEqual(result, tub)
    }

    // MARK: - Oscillators

    func test_blinker_period2() {
        let horizontal: CellsGrid = [
            [false, false, false, false, false],
            [false, false, false, false, false],
            [false, true, true, true, false],
            [false, false, false, false, false],
            [false, false, false, false, false]
        ]
        let vertical: CellsGrid = [
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, false, false, false]
        ]

        let gen1 = engine.computeNextState(horizontal)
        XCTAssertEqual(gen1, vertical)
        let gen2 = engine.computeNextState(gen1)
        XCTAssertEqual(gen2, horizontal)
    }

    func test_toad_period2() {
        let phase1: CellsGrid = [
            [false, false, false, false, false, false],
            [false, false, false, false, false, false],
            [false, false, true, true, true, false],
            [false, true, true, true, false, false],
            [false, false, false, false, false, false],
            [false, false, false, false, false, false]
        ]
        let phase2: CellsGrid = [
            [false, false, false, false, false, false],
            [false, false, false, true, false, false],
            [false, true, false, false, true, false],
            [false, true, false, false, true, false],
            [false, false, true, false, false, false],
            [false, false, false, false, false, false]
        ]

        let gen1 = engine.computeNextState(phase1)
        XCTAssertEqual(gen1, phase2)
        let gen2 = engine.computeNextState(gen1)
        XCTAssertEqual(gen2, phase1)
    }

    func test_beacon_period2() {
        let phase1: CellsGrid = [
            [false, false, false, false, false, false],
            [false, true, true, false, false, false],
            [false, true, true, false, false, false],
            [false, false, false, true, true, false],
            [false, false, false, true, true, false],
            [false, false, false, false, false, false]
        ]
        let phase2: CellsGrid = [
            [false, false, false, false, false, false],
            [false, true, true, false, false, false],
            [false, true, false, false, false, false],
            [false, false, false, false, true, false],
            [false, false, false, true, true, false],
            [false, false, false, false, false, false]
        ]

        let gen1 = engine.computeNextState(phase1)
        XCTAssertEqual(gen1, phase2)
        let gen2 = engine.computeNextState(gen1)
        XCTAssertEqual(gen2, phase1)
    }

    // MARK: - Spaceships

    func test_glider_moves() {
        let glider: CellsGrid = [
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, false, false, true, false],
            [false, true, true, true, false],
            [false, false, false, false, false]
        ]

        var state = glider
        for _ in 0..<4 {
            state = engine.computeNextState(state)
        }

        // After 4 generations (canonical glider phase)
        let expected: CellsGrid = [
            [false, false, false, false, false],
            [false, false, false, false, false],
            [false, false, false, true, false],
            [false, false, false, false, true],
            [false, false, true, true, true]
        ]
        XCTAssertEqual(state, expected)
    }

    // MARK: - Birth and Death Rules

    func test_birthRule_exactlyThreeNeighbors() {
        let grid: CellsGrid = [
            [true, true, false],
            [true, false, false],
            [false, false, false]
        ]
        let expected: CellsGrid = [
            [true, true, false],
            [true, true, false],
            [false, false, false]
        ]
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, expected)
    }

    func test_deathByUnderpopulation() {
        let grid: CellsGrid = [
            [false, true, false],
            [false, false, false],
            [false, false, false]
        ]
        let expected: CellsGrid = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ]
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, expected)
    }

    func test_deathByOverpopulation() {
        let grid: CellsGrid = [
            [true, true, true],
            [true, true, true],
            [false, false, false]
        ]
        let expected: CellsGrid = [
            [true, false, true],
            [true, false, true],
            [false, true, false]
        ]
        let result = engine.computeNextState(grid)
        XCTAssertEqual(result, expected)
    }

    func test_survivalWithTwoNeighbors() {
        let grid: CellsGrid = [
            [true, true, false],
            [true, false, false],
            [false, false, false]
        ]
        let result = engine.computeNextState(grid)
        XCTAssertTrue(result[0][0]) // Should survive with 2 neighbors
    }

    func test_survivalWithThreeNeighbors() {
        let grid: CellsGrid = [
            [true, true, false],
            [true, true, false],
            [false, false, false]
        ]
        let result = engine.computeNextState(grid)
        XCTAssertTrue(result[0][0]) // Should survive with 3 neighbors
    }

    // MARK: - Boundary Conditions

    func test_edgeCells_correctNeighborCount() {
        let grid: CellsGrid = [
            [true, true, false],
            [false, false, false],
            [false, false, true]
        ]
        let result = engine.computeNextState(grid)
        // Top-left corner has only 1 neighbor, should die
        XCTAssertFalse(result[0][0])
        // Bottom-right corner has no neighbors, should die
        XCTAssertFalse(result[2][2])
    }

    // MARK: - Multi-Generation Tests

    func test_computeStateAtGeneration_zero() {
        let initial: CellsGrid = [
            [true, false, true],
            [false, true, false],
            [true, false, true]
        ]
        let result = engine.computeStateAtGeneration(initial, generation: 0)
        XCTAssertEqual(result, initial)
    }

    func test_computeStateAtGeneration_multiple() {
        let blinker: CellsGrid = [
            [false, false, false],
            [true, true, true],
            [false, false, false]
        ]

        // Generation 1 should be vertical
        let gen1 = engine.computeStateAtGeneration(blinker, generation: 1)
        let expectedGen1: CellsGrid = [
            [false, true, false],
            [false, true, false],
            [false, true, false]
        ]
        XCTAssertEqual(gen1, expectedGen1)

        // Generation 2 should be back to horizontal
        let gen2 = engine.computeStateAtGeneration(blinker, generation: 2)
        XCTAssertEqual(gen2, blinker)

        // Generation 10 should be horizontal (even)
        let gen10 = engine.computeStateAtGeneration(blinker, generation: 10)
        XCTAssertEqual(gen10, blinker)

        // Generation 11 should be vertical (odd)
        let gen11 = engine.computeStateAtGeneration(blinker, generation: 11)
        XCTAssertEqual(gen11, expectedGen1)
    }

    func test_computeStateAtGeneration_stable() {
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true, true, false],
            [false, true, true, false],
            [false, false, false, false]
        ]

        // Should remain stable at any generation
        for generation in 1...10 {
            let result = engine.computeStateAtGeneration(block, generation: generation)
            XCTAssertEqual(result, block, "Block should remain stable at generation \(generation)")
        }
    }

    // MARK: - Performance Tests

    func test_performance_smallGrid() {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 10), count: 10)
        measure {
            _ = engine.computeNextState(grid)
        }
    }

    func test_performance_mediumGrid() {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 50), count: 50)
        measure {
            _ = engine.computeNextState(grid)
        }
    }

    func test_performance_largeGrid() {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 100), count: 100)
        measure {
            _ = engine.computeNextState(grid)
        }
    }

    func test_performance_multiGeneration() {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 50), count: 50)
        measure {
            _ = engine.computeStateAtGeneration(grid, generation: 100)
        }
    }
}

// MARK: - GameRules Tests

final class GameRulesTests: XCTestCase {
    func test_shouldCellLive_aliveWithZeroNeighbors_dies() {
        XCTAssertFalse(GameRules.shouldCellLive(isAlive: true, neighborCount: 0))
    }

    func test_shouldCellLive_aliveWithOneNeighbor_dies() {
        XCTAssertFalse(GameRules.shouldCellLive(isAlive: true, neighborCount: 1))
    }

    func test_shouldCellLive_aliveWithTwoNeighbors_survives() {
        XCTAssertTrue(GameRules.shouldCellLive(isAlive: true, neighborCount: 2))
    }

    func test_shouldCellLive_aliveWithThreeNeighbors_survives() {
        XCTAssertTrue(GameRules.shouldCellLive(isAlive: true, neighborCount: 3))
    }

    func test_shouldCellLive_aliveWithFourNeighbors_dies() {
        XCTAssertFalse(GameRules.shouldCellLive(isAlive: true, neighborCount: 4))
    }

    func test_shouldCellLive_deadWithTwoNeighbors_staysDead() {
        XCTAssertFalse(GameRules.shouldCellLive(isAlive: false, neighborCount: 2))
    }

    func test_shouldCellLive_deadWithThreeNeighbors_becomesAlive() {
        XCTAssertTrue(GameRules.shouldCellLive(isAlive: false, neighborCount: 3))
    }

    func test_shouldCellLive_deadWithFourNeighbors_staysDead() {
        XCTAssertFalse(GameRules.shouldCellLive(isAlive: false, neighborCount: 4))
    }

    func test_countNeighbors_centerCell() {
        let grid: CellsGrid = [
            [true, true, true],
            [true, false, true],
            [true, true, true]
        ]
        let count = GameRules.countNeighbors(grid, x: 1, y: 1)
        XCTAssertEqual(count, 8)
    }

    func test_countNeighbors_cornerCell() {
        let grid: CellsGrid = [
            [false, true, false],
            [true, true, false],
            [false, false, false]
        ]
        let count = GameRules.countNeighbors(grid, x: 0, y: 0)
        XCTAssertEqual(count, 3)
    }

    func test_countNeighbors_edgeCell() {
        let grid: CellsGrid = [
            [true, false, true],
            [true, false, true],
            [true, false, true]
        ]
        let count = GameRules.countNeighbors(grid, x: 1, y: 0)
        XCTAssertEqual(count, 2)
    }

    func test_countNeighbors_emptyGrid() {
        let grid: CellsGrid = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ]
        let count = GameRules.countNeighbors(grid, x: 1, y: 1)
        XCTAssertEqual(count, 0)
    }
}
