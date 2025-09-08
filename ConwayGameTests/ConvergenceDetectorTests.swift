import XCTest
@testable import ConwayGame

final class ConvergenceDetectorTests: XCTestCase {
    private var detector: DefaultConvergenceDetector!
    
    override func setUp() {
        super.setUp()
        detector = DefaultConvergenceDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Extinction Tests
    
    func test_checkConvergence_emptyGrid_returnsExtinct() {
        let emptyGrid: CellsGrid = []
        let history = Set<String>()
        let result = detector.checkConvergence(emptyGrid, history: history)
        XCTAssertEqual(result, .extinct)
    }
    
    func test_checkConvergence_allDeadCells_returnsExtinct() {
        let deadGrid: CellsGrid = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ]
        let history = Set<String>()
        let result = detector.checkConvergence(deadGrid, history: history)
        XCTAssertEqual(result, .extinct)
    }
    
    func test_checkConvergence_singleDeadCell_returnsExtinct() {
        let grid: CellsGrid = [[false]]
        let history = Set<String>()
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertEqual(result, .extinct)
    }
    
    func test_checkConvergence_largeDeadGrid_returnsExtinct() {
        let grid = Array(repeating: Array(repeating: false, count: 100), count: 100)
        let history = Set<String>()
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertEqual(result, .extinct)
    }
    
    // MARK: - Living Grid Tests
    
    func test_checkConvergence_livingCells_returnsContinuing() {
        let grid: CellsGrid = [
            [false, true,  false],
            [false, false, false],
            [false, false, true]
        ]
        let history = Set<String>()
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertEqual(result, .continuing)
    }
    
    func test_checkConvergence_singleLiveCell_returnsContinuing() {
        let grid: CellsGrid = [[true]]
        let history = Set<String>()
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertEqual(result, .continuing)
    }
    
    // MARK: - Cycle Detection Tests
    
    func test_checkConvergence_repeatedState_returnsCyclical() {
        let grid: CellsGrid = [
            [false, true,  false],
            [true,  false, true],
            [false, true,  false]
        ]
        let hash = BoardHashing.hash(for: grid)
        var history = Set<String>()
        history.insert(hash)
        
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertEqual(result, .cyclical(period: 0))
    }
    
    func test_checkConvergence_stillLife_detectsCycle() {
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        var history = Set<String>()
        
        // First check - should be continuing
        let result1 = detector.checkConvergence(block, history: history)
        XCTAssertEqual(result1, .continuing)
        
        // Add to history and check again - should detect cycle
        history.insert(BoardHashing.hash(for: block))
        let result2 = detector.checkConvergence(block, history: history)
        XCTAssertEqual(result2, .cyclical(period: 0))
    }
    
    func test_checkConvergence_differentStates_returnsContinuing() {
        let grid1: CellsGrid = [
            [true,  false, false],
            [false, true,  false],
            [false, false, true]
        ]
        let grid2: CellsGrid = [
            [false, true,  false],
            [true,  false, true],
            [false, true,  false]
        ]
        
        var history = Set<String>()
        history.insert(BoardHashing.hash(for: grid1))
        
        let result = detector.checkConvergence(grid2, history: history)
        XCTAssertEqual(result, .continuing)
    }
    
    // MARK: - History Management Tests
    
    func test_checkConvergence_emptyHistory_neverReturnsCyclical() {
        let grid: CellsGrid = [
            [true,  true,  false],
            [false, false, true],
            [true,  false, false]
        ]
        let history = Set<String>()
        let result = detector.checkConvergence(grid, history: history)
        XCTAssertNotEqual(result, .cyclical(period: 0))
    }
    
    func test_checkConvergence_largeHistory_correctlyDetectsCycle() {
        let targetGrid: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        var history = Set<String>()
        
        // Add many different states to history
        for i in 0..<100 {
            let randomGrid: CellsGrid = [
                [i % 2 == 0, i % 3 == 0, i % 5 == 0],
                [i % 7 == 0, i % 11 == 0, i % 13 == 0],
                [i % 17 == 0, i % 19 == 0, i % 23 == 0]
            ]
            history.insert(BoardHashing.hash(for: randomGrid))
        }
        
        // Target grid not in history - should continue
        let result1 = detector.checkConvergence(targetGrid, history: history)
        XCTAssertEqual(result1, .continuing)
        
        // Add target to history
        history.insert(BoardHashing.hash(for: targetGrid))
        
        // Now should detect cycle
        let result2 = detector.checkConvergence(targetGrid, history: history)
        XCTAssertEqual(result2, .cyclical(period: 0))
    }
    
    // MARK: - Integration with BoardHashing Tests
    
    func test_checkConvergence_identicalGrids_produceIdenticalHashes() {
        let grid1: CellsGrid = [
            [true,  false, true,  false],
            [false, true,  false, true],
            [true,  false, true,  false],
            [false, true,  false, true]
        ]
        let grid2 = grid1 // Identical grid
        
        var history = Set<String>()
        history.insert(BoardHashing.hash(for: grid1))
        
        // Should detect as cyclical since grid2 is identical to grid1
        let result = detector.checkConvergence(grid2, history: history)
        XCTAssertEqual(result, .cyclical(period: 0))
    }
    
    func test_checkConvergence_slightlyDifferentGrids_noCycle() {
        let grid1: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        let grid2: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, false] // One cell different
        ]
        
        var history = Set<String>()
        history.insert(BoardHashing.hash(for: grid1))
        
        // Should not detect as cyclical since grids are different
        let result = detector.checkConvergence(grid2, history: history)
        XCTAssertEqual(result, .continuing)
    }
    
    // MARK: - Performance Tests
    
    func test_performance_extinctionCheck_smallGrid() {
        let grid = Array(repeating: Array(repeating: false, count: 10), count: 10)
        let history = Set<String>()
        
        measure {
            _ = detector.checkConvergence(grid, history: history)
        }
    }
    
    func test_performance_extinctionCheck_largeGrid() {
        let grid = Array(repeating: Array(repeating: false, count: 100), count: 100)
        let history = Set<String>()
        
        measure {
            _ = detector.checkConvergence(grid, history: history)
        }
    }
    
    func test_performance_cycleDetection_largeHistory() {
        let grid: CellsGrid = [
            [true,  false, true,  false, true],
            [false, true,  false, true,  false],
            [true,  false, true,  false, true],
            [false, true,  false, true,  false],
            [true,  false, true,  false, true]
        ]
        
        var history = Set<String>()
        // Create a large history
        for i in 0..<10000 {
            history.insert("hash_\(i)")
        }
        
        measure {
            _ = detector.checkConvergence(grid, history: history)
        }
    }
}

// MARK: - BoardHashing Tests

final class BoardHashingTests: XCTestCase {
    
    func test_hash_emptyGrid_returnsEmptyString() {
        let grid: CellsGrid = []
        let hash = BoardHashing.hash(for: grid)
        XCTAssertEqual(hash, "")
    }
    
    func test_hash_singleCell_true() {
        let grid: CellsGrid = [[true]]
        let hash = BoardHashing.hash(for: grid)
        XCTAssertNotEqual(hash, "")
        XCTAssertTrue(hash.count > 0)
    }
    
    func test_hash_singleCell_false() {
        let grid: CellsGrid = [[false]]
        let hash = BoardHashing.hash(for: grid)
        XCTAssertNotEqual(hash, "")
        XCTAssertTrue(hash.count > 0)
    }
    
    func test_hash_identicalGrids_produceSameHash() {
        let grid1: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        let grid2 = grid1
        
        let hash1 = BoardHashing.hash(for: grid1)
        let hash2 = BoardHashing.hash(for: grid2)
        
        XCTAssertEqual(hash1, hash2)
    }
    
    func test_hash_differentGrids_produceDifferentHashes() {
        let grid1: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        let grid2: CellsGrid = [
            [false, true,  false],
            [true,  false, true],
            [false, true,  false]
        ]
        
        let hash1 = BoardHashing.hash(for: grid1)
        let hash2 = BoardHashing.hash(for: grid2)
        
        XCTAssertNotEqual(hash1, hash2)
    }
    
    func test_hash_slightlyDifferentGrids_produceDifferentHashes() {
        let grid1: CellsGrid = [
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  true]
        ]
        let grid2: CellsGrid = [
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  false] // One cell different
        ]
        
        let hash1 = BoardHashing.hash(for: grid1)
        let hash2 = BoardHashing.hash(for: grid2)
        
        XCTAssertNotEqual(hash1, hash2)
    }
    
    func test_hash_largeGrid_performsWell() {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 100), count: 100)
        
        measure {
            _ = BoardHashing.hash(for: grid)
        }
    }
    
    func test_hash_consistency() {
        let grid: CellsGrid = [
            [true,  false, true,  false],
            [false, true,  false, true],
            [true,  false, true,  false],
            [false, true,  false, true]
        ]
        
        // Hash should be consistent across multiple calls
        let hash1 = BoardHashing.hash(for: grid)
        let hash2 = BoardHashing.hash(for: grid)
        let hash3 = BoardHashing.hash(for: grid)
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash2, hash3)
    }
    
    func test_hash_base64Valid() {
        let grid: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        let hash = BoardHashing.hash(for: grid)
        
        // Should be valid base64
        XCTAssertNotNil(Data(base64Encoded: hash))
    }
    
    func test_hash_differentSizes_differentHashes() {
        let grid3x3: CellsGrid = [
            [true,  true,  true],
            [true,  true,  true],
            [true,  true,  true]
        ]
        let grid4x4: CellsGrid = [
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  true],
            [true,  true,  true,  true]
        ]
        
        let hash1 = BoardHashing.hash(for: grid3x3)
        let hash2 = BoardHashing.hash(for: grid4x4)
        
        XCTAssertNotEqual(hash1, hash2)
    }
}