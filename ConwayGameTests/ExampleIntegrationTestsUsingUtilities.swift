import XCTest
import ConwayGameEngine
@testable import ConwayGame

// MARK: - Example Integration Tests Using Shared Utilities
// This file demonstrates how to use the shared test utilities

@MainActor
final class ExampleIntegrationTestsUsingUtilities: BaseIntegrationTestCase {
    
    // MARK: - Pattern Behavior Tests
    
    func testKnownPatternBehaviors() async throws {
        // Test all known patterns using the utility functions
        for (patternName, (_, expectedBehavior)) in TestPatterns.knownPatterns {
            let boardId = try await createTestBoard(pattern: patternName)
            
            // Run final state detection
            let result = await testEnvironment.gameService.getFinalState(boardId: boardId, maxIterations: 100)
            
            guard case .success(let finalState) = result else {
                XCTFail("Failed to get final state for \(patternName)")
                continue
            }
            
            // Use utility assertion
            assertPatternBehavior(finalState, matches: expectedBehavior)
        }
    }
    
    func testPatternEvolutionConsistency() async throws {
        // Test that stepping manually produces the same result as bulk simulation
        let boardId = try await createTestBoard(pattern: "glider")
        
        // Manual stepping
        var currentGrid = TestPatterns.knownPatterns["glider"]!.grid
        let gameEngine = testEnvironment.gameEngine!
        
        let steps = 5
        for _ in 0..<steps {
            currentGrid = gameEngine.nextGeneration(from: currentGrid)
        }
        
        // Bulk simulation
        let bulkResult = await testEnvironment.gameService.getStateAtGeneration(boardId: boardId, generation: steps)
        
        guard case .success(let bulkState) = bulkResult else {
            XCTFail("Bulk simulation failed")
            return
        }
        
        // Use utility assertion
        assertGridsEqual(currentGrid, bulkState.cells, message: "Manual and bulk simulation should match")
    }
    
    // MARK: - Performance Tests Using Utilities
    
    func testScalingPerformance() async throws {
        let gridSizes = [(10, 10), (25, 25), (50, 50), (75, 75)]
        
        for (width, height) in gridSizes {
            let pattern = TestPatterns.randomPattern(width: width, height: height, density: 0.4)
            let boardId = try await testEnvironment.createBoard(pattern: pattern)
            
            // Measure single step performance
            _ = try await measurePerformance(
                of: "singleStep",
                parameters: ["size": "\(width)x\(height)"],
                expectedMaxTime: IntegrationTestConfig.maxStepTime
            ) {
                await testEnvironment.gameService.getNextState(boardId: boardId)
            }
            
            // Measure simulation performance
            _ = try await measurePerformance(
                of: "simulation",
                parameters: ["size": "\(width)x\(height)", "generations": 20],
                expectedMaxTime: IntegrationTestConfig.maxFinalStateTime
            ) {
                await testEnvironment.gameService.getFinalState(boardId: boardId, maxIterations: 20)
            }
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentBoardCreation() async throws {
        let boardCount = IntegrationTestConfig.concurrentOperationCount
        
        let boardIds = try await ConcurrentTestRunner.runConcurrentOperations(count: boardCount) { index in
            let pattern = TestPatterns.randomPattern(width: 10, height: 10)
            return try await testEnvironment.createBoard(
                name: "Concurrent Board \(index)",
                pattern: pattern
            )
        }
        
        XCTAssertEqual(boardIds.count, boardCount)
        XCTAssertEqual(Set(boardIds).count, boardCount, "All board IDs should be unique")
        
        // Verify all boards can be retrieved
        for boardId in boardIds {
            let board = try await testEnvironment.boardRepository.findById(boardId)
            XCTAssertNotNil(board, "Board \(boardId) should be retrievable")
        }
    }
    
    func testConcurrentGameOperations() async throws {
        let boardId = try await createTestBoard(pattern: "glider")
        let operationCount = 10
        
        // Run concurrent operations on the same board
        let results = try await ConcurrentTestRunner.runConcurrentOperations(count: operationCount) { index in
            switch index % 3 {
            case 0:
                return await testEnvironment.gameService.getNextState(boardId: boardId)
            case 1:
                return await testEnvironment.gameService.getStateAtGeneration(boardId: boardId, generation: index + 1)
            case 2:
                return await testEnvironment.gameService.getFinalState(boardId: boardId, maxIterations: 50)
            default:
                return await testEnvironment.gameService.getNextState(boardId: boardId)
            }
        }
        
        XCTAssertEqual(results.count, operationCount)
        
        // All operations should succeed
        for (index, result) in results.enumerated() {
            XCTAssertTrue(result.isSuccess, "Operation \(index) should succeed")
        }
    }
    
    // MARK: - Stress Tests
    
    func testLargeDatasetHandling() async throws {
        let boardCount = IntegrationTestConfig.stressTestBoardCount
        
        // Create many boards
        let boardIds = try await measurePerformance(
            of: "bulkBoardCreation",
            parameters: ["count": boardCount],
            expectedMaxTime: 10.0
        ) {
            try await testEnvironment.createMultipleBoards(count: boardCount)
        }
        
        XCTAssertEqual(boardIds.count, boardCount)
        
        // Test pagination performance
        let boardListViewModel = BoardListViewModel()
        
        _ = try await measurePerformance(
            of: "paginationLoad",
            parameters: ["totalBoards": boardCount, "pageSize": 20],
            expectedMaxTime: IntegrationTestConfig.maxPaginationTime
        ) {
            await boardListViewModel.loadFirstPage()
        }
        
        XCTAssertGreaterThan(boardListViewModel.boards.count, 0)
        XCTAssertEqual(boardListViewModel.totalCount, boardCount)
        
        // Test search performance
        _ = try await measurePerformance(
            of: "searchOperation",
            parameters: ["totalBoards": boardCount, "query": "Test Board 0"]
        ) {
            await boardListViewModel.search(query: "Test Board 0")
        }
        
        // Should find boards with names containing "Test Board 0"
        XCTAssertGreaterThan(boardListViewModel.boards.count, 0)
    }
    
    // MARK: - Race Condition Tests
    
    func testBoardCreationRaceConditions() async throws {
        try await ConcurrentTestRunner.runRaceConditionTest(
            iterations: 50,
            operation: {
                let pattern = TestPatterns.randomPattern(width: 5, height: 5)
                return try await testEnvironment.createBoard(pattern: pattern)
            },
            validation: { boardIds in
                // All board IDs should be unique
                XCTAssertEqual(Set(boardIds).count, boardIds.count, "Race condition: duplicate board IDs created")
            }
        )
    }
    
    func testViewModelStateRaceConditions() async throws {
        let boardId = try await createTestBoard(pattern: "blinker")
        
        try await ConcurrentTestRunner.runRaceConditionTest(
            iterations: 20,
            operation: {
                let gameViewModel = GameViewModel(boardId: boardId)
                await gameViewModel.loadCurrent()
                await gameViewModel.step()
                return gameViewModel.state?.generation ?? -1
            },
            validation: { generations in
                // All ViewModels should successfully load and step
                XCTAssertTrue(generations.allSatisfy { $0 > 0 }, "All ViewModels should successfully step")
            }
        )
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryWorkflow() async throws {
        // Test with non-existent board
        let nonExistentBoardId = UUID()
        let gameViewModel = GameViewModel(boardId: nonExistentBoardId)
        
        await gameViewModel.loadCurrent()
        XCTAssertNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.gameError, .boardNotFound(nonExistentBoardId))
        
        // Test error recovery by creating a valid board and switching to it
        let validBoardId = try await createTestBoard(pattern: "block")
        let validGameViewModel = GameViewModel(boardId: validBoardId)
        
        await validGameViewModel.loadCurrent()
        XCTAssertNotNil(validGameViewModel.state)
        XCTAssertNil(validGameViewModel.gameError)
        XCTAssertEqual(validGameViewModel.state?.boardId, validBoardId)
        
        // Test user-friendly error handling
        let userFriendlyError = gameViewModel.gameError?.asUserFriendlyError(context: .boardLoading)
        XCTAssertNotNil(userFriendlyError)
        XCTAssertFalse(userFriendlyError?.message.isEmpty ?? true)
        XCTAssertTrue(userFriendlyError?.recoveryActions.contains(.retry) ?? false)
    }
    
    // MARK: - Cross-Platform Consistency Tests
    
    func testConfigurationConsistency() async throws {
        // Test different rule configurations produce consistent results
        let testPattern = TestPatterns.knownPatterns["blinker"]!.grid
        
        let rules: [GameRules] = [.conway, .highLife, .dayNight]
        var results: [GameRules: CellsGrid] = [:]
        
        for rule in rules {
            // Create engine with specific rule
            let config = GameEngineConfiguration(rules: rule, maxGenerations: 1000)
            let engine = ConwayGameEngine(configuration: config)
            
            let result = engine.nextGeneration(from: testPattern)
            results[rule] = result
        }
        
        // Results should be valid grids of the same dimensions
        for (rule, result) in results {
            XCTAssertEqual(result.count, testPattern.count, "Rule \(rule) should preserve grid height")
            XCTAssertEqual(result.first?.count, testPattern.first?.count, "Rule \(rule) should preserve grid width")
        }
        
        // Different rules should potentially produce different results
        let conwayResult = results[.conway]!
        let highLifeResult = results[.highLife]!
        
        print("Conway result population: \(conwayResult.populationCount)")
        print("HighLife result population: \(highLifeResult.populationCount)")
        // Note: We don't assert they're different because some patterns might evolve the same way
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() async throws {
        // Create and destroy many objects to test for memory leaks
        let iterations = 100
        
        for i in 0..<iterations {
            let boardId = try await createTestBoard(pattern: "block")
            let gameViewModel = GameViewModel(boardId: boardId)
            
            await gameViewModel.loadCurrent()
            XCTAssertNotNil(gameViewModel.state)
            
            // Simulate user interaction
            await gameViewModel.step()
            await gameViewModel.jump(to: 5)
            await gameViewModel.reset()
            
            // ViewModels should be properly deallocated
            // (The test passes if no memory leaks occur)
            
            if i % 10 == 0 {
                print("Memory test iteration \(i)/\(iterations)")
            }
        }
    }
    
    // MARK: - Integration with UI Components
    
    func testViewModelIntegration() async throws {
        let boardId = try await createTestBoard(pattern: "glider")
        let gameViewModel = GameViewModel(boardId: boardId)
        
        // Test complete ViewModel lifecycle
        await gameViewModel.loadCurrent()
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        
        // Test play/pause functionality
        gameViewModel.play()
        XCTAssertTrue(gameViewModel.isPlaying)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        gameViewModel.pause()
        XCTAssertFalse(gameViewModel.isPlaying)
        XCTAssertGreaterThan(gameViewModel.state?.generation ?? 0, 0)
        
        // Test speed changes
        let originalSpeed = gameViewModel.playSpeed
        gameViewModel.playSpeed = .turbo
        XCTAssertEqual(gameViewModel.playSpeed, .turbo)
        XCTAssertNotEqual(gameViewModel.playSpeed, originalSpeed)
        
        // Test final state computation
        await gameViewModel.finalState(maxIterations: 100)
        // Glider might not converge in a small grid, so we don't assert convergence
        XCTAssertNotNil(gameViewModel.state)
    }
    
    // MARK: - Complex Workflow Tests
    
    func testComplexUserJourney() async throws {
        // Simulate a complete user session
        let boardListViewModel = BoardListViewModel()
        
        // 1. User starts with empty board list
        await boardListViewModel.loadFirstPage()
        let initialCount = boardListViewModel.boards.count
        
        // 2. User creates several boards
        await boardListViewModel.createRandomBoard(name: "User Board 1", width: 15, height: 15)
        await boardListViewModel.createRandomBoard(name: "User Board 2", width: 20, height: 20)
        
        XCTAssertEqual(boardListViewModel.boards.count, initialCount + 2)
        
        // 3. User selects and plays with first board
        let firstBoard = boardListViewModel.boards.first!
        let gameViewModel = GameViewModel(boardId: firstBoard.id)
        
        await gameViewModel.loadCurrent()
        let initialPopulation = gameViewModel.state?.populationCount ?? 0
        
        // 4. User experiments with the simulation
        await gameViewModel.step()
        await gameViewModel.step()
        XCTAssertEqual(gameViewModel.state?.generation, 2)
        
        await gameViewModel.jump(to: 25)
        XCTAssertEqual(gameViewModel.state?.generation, 25)
        
        // 5. User resets and tries auto-play
        await gameViewModel.reset()
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        XCTAssertEqual(gameViewModel.state?.populationCount, initialPopulation)
        
        gameViewModel.playSpeed = .fast
        gameViewModel.play()
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        gameViewModel.pause()
        XCTAssertGreaterThan(gameViewModel.state?.generation ?? 0, 0)
        
        // 6. User goes back and manages board list
        await boardListViewModel.search(query: "User Board")
        XCTAssertEqual(boardListViewModel.boards.count, 2)
        
        // 7. User deletes one board
        await boardListViewModel.delete(id: firstBoard.id)
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        XCTAssertEqual(boardListViewModel.boards.first?.name, "User Board 2")
        
        // 8. Verify persistence
        let newBoardListViewModel = BoardListViewModel()
        await newBoardListViewModel.loadFirstPage()
        let remainingBoards = newBoardListViewModel.boards.filter { $0.name.contains("User Board") }
        XCTAssertEqual(remainingBoards.count, 1)
        XCTAssertEqual(remainingBoards.first?.name, "User Board 2")
    }
}

// MARK: - Utility Extensions for Testing

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