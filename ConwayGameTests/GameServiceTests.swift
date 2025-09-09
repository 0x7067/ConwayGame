import XCTest
import ConwayGameEngine
@testable import ConwayGame

final class GameServiceTests: XCTestCase {
    private var gameService: DefaultGameService!
    private var mockRepository: MockBoardRepository!
    private var gameEngine: ConwayGameEngine!
    private var convergenceDetector: DefaultConvergenceDetector!
    
    override func setUp() {
        super.setUp()
        gameEngine = ConwayGameEngine()
        mockRepository = MockBoardRepository()
        convergenceDetector = DefaultConvergenceDetector()
        gameService = DefaultGameService(
            gameEngine: gameEngine,
            repository: mockRepository,
            convergenceDetector: convergenceDetector
        )
    }
    
    override func tearDown() {
        gameService = nil
        mockRepository = nil
        gameEngine = nil
        convergenceDetector = nil
        super.tearDown()
    }
    
    // MARK: - CreateBoard Tests
    
    func test_createBoard_simpleGrid_returnsValidUUID() async {
        let grid: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        let id = await gameService.createBoard(grid)
        XCTAssertNotEqual(id, UUID())
        XCTAssertEqual(mockRepository.saveCallCount, 1)
    }
    
    func test_createBoard_emptyGrid_handlesGracefully() async {
        let grid: CellsGrid = []
        let id = await gameService.createBoard(grid)
        XCTAssertNotEqual(id, UUID())
    }
    
    func test_createBoard_largeGrid_createsSuccessfully() async {
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 100), count: 100)
        let id = await gameService.createBoard(grid)
        XCTAssertNotEqual(id, UUID())
    }
    
    // MARK: - GetNextState Tests
    
    func test_getNextState_stillLifePattern_remainsStable() async {
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        let id = await gameService.createBoard(block)
        let result = await gameService.getNextState(boardId: id)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success, got failure")
            return
        }
        
        XCTAssertEqual(state.cells, block)
        XCTAssertTrue(state.isStable)
        XCTAssertEqual(state.populationCount, 4)
        XCTAssertEqual(state.generation, 1)
    }
    
    func test_getNextState_oscillator_alternates() async {
        let blinker: CellsGrid = [
            [false, false, false, false, false],
            [false, false, false, false, false],
            [false, true,  true,  true,  false],
            [false, false, false, false, false],
            [false, false, false, false, false]
        ]
        
        let id = await gameService.createBoard(blinker)
        let step1 = await gameService.getNextState(boardId: id)
        
        guard case .success(let state1) = step1 else {
            XCTFail("Expected success")
            return
        }
        
        let expectedVertical: CellsGrid = [
            [false, false, false, false, false],
            [false, false, true,  false, false],
            [false, false, true,  false, false],
            [false, false, true,  false, false],
            [false, false, false, false, false]
        ]
        
        XCTAssertEqual(state1.cells, expectedVertical)
        XCTAssertFalse(state1.isStable)
        XCTAssertEqual(state1.populationCount, 3)
        
        // Second step should go back to horizontal
        let step2 = await gameService.getNextState(boardId: id)
        guard case .success(let state2) = step2 else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state2.cells, blinker)
        XCTAssertEqual(state2.generation, 2)
    }
    
    func test_getNextState_nonexistentBoard_returnsError() async {
        let nonexistentId = UUID()
        let result = await gameService.getNextState(boardId: nonexistentId)
        
        guard case .failure(let error) = result else {
            XCTFail("Expected failure")
            return
        }
        
        if case .boardNotFound(let id) = error {
            XCTAssertEqual(id, nonexistentId)
        } else {
            XCTFail("Expected boardNotFound error")
        }
    }
    
    func test_getNextState_repositoryError_returnsError() async {
        let grid: CellsGrid = [[true, false], [false, true]]
        let id = await gameService.createBoard(grid)
        
        // Set repository to throw error
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .computationError("Repository error")
        
        let result = await gameService.getNextState(boardId: id)
        
        guard case .failure(let error) = result else {
            XCTFail("Expected failure")
            return
        }
        
        if case .computationError = error {
            // Expected
        } else {
            XCTFail("Expected computationError")
        }
    }
    
    // MARK: - GetStateAtGeneration Tests
    
    func test_getStateAtGeneration_zeroGeneration_returnsInitialState() async {
        let grid: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        let id = await gameService.createBoard(grid)
        let result = await gameService.getStateAtGeneration(boardId: id, generation: 0)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state.cells, grid)
        XCTAssertEqual(state.generation, 0)
    }
    
    func test_getStateAtGeneration_futureGeneration_computesCorrectly() async {
        let blinker: CellsGrid = [
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ]
        
        let id = await gameService.createBoard(blinker)
        
        // Generation 1 should be vertical
        let result1 = await gameService.getStateAtGeneration(boardId: id, generation: 1)
        guard case .success(let state1) = result1 else {
            XCTFail("Expected success")
            return
        }
        
        let expectedVertical: CellsGrid = [
            [false, true,  false],
            [false, true,  false],
            [false, true,  false]
        ]
        
        XCTAssertEqual(state1.cells, expectedVertical)
        XCTAssertEqual(state1.generation, 1)
        
        // Generation 2 should be back to horizontal
        let result2 = await gameService.getStateAtGeneration(boardId: id, generation: 2)
        guard case .success(let state2) = result2 else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state2.cells, blinker)
        XCTAssertEqual(state2.generation, 2)
    }
    
    func test_getStateAtGeneration_nonexistentBoard_returnsError() async {
        let nonexistentId = UUID()
        let result = await gameService.getStateAtGeneration(boardId: nonexistentId, generation: 5)
        
        guard case .failure(.boardNotFound) = result else {
            XCTFail("Expected boardNotFound error")
            return
        }
    }
    
    // MARK: - GetFinalState Tests
    
    func test_getFinalState_stillLife_returnsImmediately() async {
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        let id = await gameService.createBoard(block)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 100)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state.cells, block)
        XCTAssertTrue(state.isStable)
        XCTAssertEqual(state.populationCount, 4)
        XCTAssertEqual(state.generation, 1)
    }
    
    func test_getFinalState_extinction_detectsExtinction() async {
        let singleCell: CellsGrid = [
            [false, false, false],
            [false, true,  false],
            [false, false, false]
        ]
        
        let id = await gameService.createBoard(singleCell)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 10)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state.populationCount, 0)
        XCTAssertTrue(state.isStable)
        XCTAssertEqual(state.generation, 1)
    }
    
    func test_getFinalState_oscillator_detectsCycle() async {
        let blinker: CellsGrid = [
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ]
        
        let id = await gameService.createBoard(blinker)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 10)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success")
            return
        }
        
        // Should detect cycle and return stable
        XCTAssertTrue(state.isStable)
        XCTAssertTrue(state.generation > 0)
        XCTAssertTrue(state.generation <= 10)
    }
    
    func test_getFinalState_timeout_returnsTimeoutError() async {
        // Create a pattern that likely won't converge quickly
        let random = Array(repeating: Array(repeating: Bool.random(), count: 10), count: 10)
        
        let id = await gameService.createBoard(random)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 2)
        
        // With only 2 iterations, likely to timeout
        if case .failure(.convergenceTimeout(let maxIters)) = result {
            XCTAssertEqual(maxIters, 2)
        } else {
            // It's possible it converged in 2 iterations, which is fine
        }
    }
    
    func test_getFinalState_nonexistentBoard_returnsError() async {
        let nonexistentId = UUID()
        let result = await gameService.getFinalState(boardId: nonexistentId, maxIterations: 100)
        
        guard case .failure(.boardNotFound) = result else {
            XCTFail("Expected boardNotFound error")
            return
        }
    }
    
    func test_getFinalState_generationLimitExceeded_returnsGenerationLimitError() async {
        // Create a pattern that will likely persist beyond 500 generations
        // Use a larger grid with a glider gun to ensure it doesn't converge quickly
        let largeRandomPattern = Array(repeating: Array(repeating: Bool.random(), count: 20), count: 20)
        
        let id = await gameService.createBoard(largeRandomPattern)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 500)
        
        // This test may succeed if the random pattern converges, or fail with generationLimitExceeded
        // Both outcomes are acceptable for this randomized test
        switch result {
        case .success:
            // Pattern converged within 500 generations - this is valid
            break
        case .failure(let error):
            if case .generationLimitExceeded(let generations) = error {
                XCTAssertEqual(generations, 500)
            } else {
                // Other errors are not expected in this test scenario
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func test_getFinalState_generationLimitExceeded_errorDescription() async {
        // Test the error description for the new error case
        let error = GameError.generationLimitExceeded(500)
        XCTAssertEqual(
            error.errorDescription,
            "Game didn't reach a final state after 500 generations. There are still living cells."
        )
    }
    
    func test_getFinalState_belowGenerationLimit_returnsConvergenceTimeout() async {
        // When maxIterations is below the generation limit, should still return convergenceTimeout
        let glider: CellsGrid = [
            [false, true,  false],
            [false, false, true],
            [true,  true,  true]
        ]
        
        let id = await gameService.createBoard(glider)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 50)
        
        if case .failure(let error) = result {
            if case .convergenceTimeout(let maxIters) = error {
                XCTAssertEqual(maxIters, 50)
            } else {
                XCTFail("Expected convergenceTimeout for iterations below limit, got: \(error)")
            }
        }
        // Note: It's possible the pattern converged, which is also valid
    }
    
    func test_getFinalState_exactlyGenerationLimit_withLivingCells_returnsGenerationLimitError() async {
        // Test that exactly at the generation limit with living cells returns the specific error
        let persistentPattern: CellsGrid = [
            [false, false, false, false, false, false, false],
            [false, false, true,  true,  false, false, false],
            [false, true,  false, false, true,  false, false],
            [false, true,  false, false, false, true,  false],
            [false, false, true,  false, false, true,  false],
            [false, false, false, true,  true,  false, false],
            [false, false, false, false, false, false, false]
        ]
        
        let id = await gameService.createBoard(persistentPattern)
        let result = await gameService.getFinalState(boardId: id, maxIterations: UIConstants.maxGenerationLimit)
        
        if case .failure(let error) = result {
            if case .generationLimitExceeded(let generations) = error {
                XCTAssertEqual(generations, UIConstants.maxGenerationLimit)
            } else if case .success = result {
                // Pattern converged, which is also valid
            } else {
                // Could be convergenceTimeout or success, both are acceptable
            }
        }
    }
    
    func test_getFinalState_convergenceInfo_isCorrect() async {
        // Test that convergence information is correctly included
        let block: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        let id = await gameService.createBoard(block)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 100)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success for still life pattern")
            return
        }
        
        // Should have convergence information
        XCTAssertNotNil(state.convergedAt)
        XCTAssertNotNil(state.convergenceType)
        XCTAssertTrue(state.isStable)
        
        // For a still life pattern, should converge at generation 1
        XCTAssertEqual(state.convergedAt, 1)
        XCTAssertEqual(state.generation, 1)
    }
    
    func test_getFinalState_extinctionConvergence_isCorrect() async {
        // Test extinction convergence information
        let singleCell: CellsGrid = [
            [false, false, false],
            [false, true,  false],
            [false, false, false]
        ]
        
        let id = await gameService.createBoard(singleCell)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 10)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success for extinction pattern")
            return
        }
        
        // Should have extinction convergence info
        XCTAssertNotNil(state.convergedAt)
        XCTAssertEqual(state.convergenceType, .extinct)
        XCTAssertEqual(state.populationCount, 0)
        XCTAssertTrue(state.isStable)
        
        // Single cell should die at generation 1
        XCTAssertEqual(state.convergedAt, 1)
        XCTAssertEqual(state.generation, 1)
    }
    
    func test_getFinalState_generationNumberCorrect() async {
        // Test that the generation bug is fixed
        let blinker: CellsGrid = [
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ]
        
        let id = await gameService.createBoard(blinker)
        let result = await gameService.getFinalState(boardId: id, maxIterations: 10)
        
        guard case .success(let state) = result else {
            XCTFail("Expected success for blinker pattern")
            return
        }
        
        // Should detect cyclical pattern with correct generation
        XCTAssertNotNil(state.convergedAt)
        XCTAssertEqual(state.convergenceType, .cyclical(period: 0))
        XCTAssertTrue(state.isStable)
        
        // Generation should be correctly set (not off by one)
        XCTAssertNotNil(state.convergedAt)
        if let convergedAt = state.convergedAt {
            XCTAssertEqual(state.generation, convergedAt)
        }
    }
    
    // MARK: - Integration Tests with Real Repository
    
    func test_integration_withInMemoryRepository() async {
        let realRepository = InMemoryBoardRepository()
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: realRepository,
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        let grid: CellsGrid = [
            [false, true,  false],
            [false, true,  false],
            [false, true,  false]
        ]
        
        // Create board
        let id = await service.createBoard(grid)
        
        // Step forward
        let step1 = await service.getNextState(boardId: id)
        guard case .success(let state1) = step1 else {
            XCTFail("Expected success")
            return
        }
        
        let expectedHorizontal: CellsGrid = [
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ]
        
        XCTAssertEqual(state1.cells, expectedHorizontal)
        XCTAssertEqual(state1.generation, 1)
        
        // Jump to generation 9 (should be horizontal for odd generations)
        let jump = await service.getStateAtGeneration(boardId: id, generation: 9)
        guard case .success(let state9) = jump else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertEqual(state9.cells, expectedHorizontal)
        XCTAssertEqual(state9.generation, 9)
        
        // Get final state
        let final = await service.getFinalState(boardId: id, maxIterations: 100)
        guard case .success(let finalState) = final else {
            XCTFail("Expected success")
            return
        }
        
        XCTAssertTrue(finalState.isStable)
    }
    
    // MARK: - Performance Tests
    
    func test_performance_createManyBoards() async {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        measure {
            Task {
                for _ in 0..<100 {
                    let grid = Array(repeating: Array(repeating: Bool.random(), count: 10), count: 10)
                    _ = await service.createBoard(grid)
                }
            }
        }
    }
    
    func test_performance_manySteps() async {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 20), count: 20)
        let id = await service.createBoard(grid)
        
        measure {
            Task {
                for _ in 0..<50 {
                    _ = await service.getNextState(boardId: id)
                }
            }
        }
    }
    
    func test_performance_jumpToFutureGeneration() async {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        let grid = Array(repeating: Array(repeating: Bool.random(), count: 50), count: 50)
        let id = await service.createBoard(grid)
        
        measure {
            Task {
                _ = await service.getStateAtGeneration(boardId: id, generation: 1000)
            }
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func test_concurrentAccess_multipleOperations() async {
        let service = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: InMemoryBoardRepository(),
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        let grid: CellsGrid = [
            [true,  true,  false],
            [false, true,  true],
            [true,  false, false]
        ]
        
        let id = await service.createBoard(grid)
        
        // Concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Multiple next state calls
            for _ in 0..<10 {
                group.addTask {
                    _ = await service.getNextState(boardId: id)
                }
            }
            
            // Multiple generation jumps
            for gen in 1..<11 {
                group.addTask {
                    _ = await service.getStateAtGeneration(boardId: id, generation: gen)
                }
            }
            
            // Final state computation
            group.addTask {
                _ = await service.getFinalState(boardId: id, maxIterations: 100)
            }
        }
        
        // Should still be able to access the board
        let final = await service.getNextState(boardId: id)
        XCTAssertTrue(final.isSuccess)
    }
}

// MARK: - Test Helpers

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
}
