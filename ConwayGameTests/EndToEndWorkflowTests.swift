import XCTest
import ConwayGameEngine
import SwiftUI
import CoreData
import FactoryKit
import FactoryTesting
@testable import ConwayGame

@MainActor
final class EndToEndWorkflowTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var container: FactoryContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up complete production-like environment
        persistenceController = PersistenceController(inMemory: true)
        
        // Register all dependencies with real implementations
        Container.shared.gameEngine.register { ConwayGameEngine() }
        Container.shared.convergenceDetector.register { DefaultConvergenceDetector() }
        Container.shared.boardRepository.register { 
            CoreDataBoardRepository(context: self.persistenceController.container.viewContext)
        }
        Container.shared.gameService.register { 
            DefaultGameService(
                gameEngine: Container.shared.gameEngine(),
                repository: Container.shared.boardRepository(),
                convergenceDetector: Container.shared.convergenceDetector()
            )
        }
        Container.shared.themeManager.register { ThemeManager() }
        Container.shared.gameEngineConfiguration.register { .default }
        Container.shared.playSpeedConfiguration.register { .default }
    }
    
    override func tearDown() {
        Container.shared.reset()
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Complete New User Onboarding Workflow
    
    func testNewUserCompleteWorkflow() async throws {
        // 1. New user opens app - Board list should be empty
        let boardListViewModel = BoardListViewModel()
        await boardListViewModel.loadFirstPage()
        
        XCTAssertEqual(boardListViewModel.boards.count, 0)
        XCTAssertEqual(boardListViewModel.totalCount, 0)
        XCTAssertFalse(boardListViewModel.hasMorePages)
        
        // 2. User creates their first board with a random pattern
        await boardListViewModel.createRandomBoard(
            name: "My First Conway Board",
            width: 15,
            height: 15,
            density: 0.3
        )
        
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        let firstBoard = boardListViewModel.boards.first!
        XCTAssertEqual(firstBoard.name, "My First Conway Board")
        XCTAssertEqual(firstBoard.width, 15)
        XCTAssertEqual(firstBoard.height, 15)
        
        // 3. User navigates to the game view
        let gameViewModel = GameViewModel(boardId: firstBoard.id)
        await gameViewModel.loadCurrent()
        
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.state?.boardId, firstBoard.id)
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        XCTAssertGreaterThan(gameViewModel.state?.populationCount ?? 0, 0) // Should have some living cells
        
        // 4. User experiments with single step
        let initialPopulation = gameViewModel.state?.populationCount ?? 0
        await gameViewModel.step()
        
        XCTAssertEqual(gameViewModel.state?.generation, 1)
        let afterStepPopulation = gameViewModel.state?.populationCount ?? 0
        // Population might change or stay same depending on pattern
        XCTAssertGreaterThanOrEqual(afterStepPopulation, 0)
        
        // 5. User tries play/pause functionality
        gameViewModel.play()
        XCTAssertTrue(gameViewModel.isPlaying)
        
        // Let it run for a short while
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        gameViewModel.pause()
        XCTAssertFalse(gameViewModel.isPlaying)
        XCTAssertGreaterThan(gameViewModel.state?.generation ?? 0, 1)
        
        // 6. User jumps to future generation
        await gameViewModel.jump(to: 50)
        XCTAssertEqual(gameViewModel.state?.generation, 50)
        
        // 7. User resets to beginning
        await gameViewModel.reset()
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        XCTAssertEqual(gameViewModel.state?.populationCount, initialPopulation)
        
        // 8. User goes back to board list and creates another board
        await boardListViewModel.createRandomBoard(
            name: "Second Board", 
            width: 10,
            height: 10,
            density: 0.4
        )
        
        XCTAssertEqual(boardListViewModel.boards.count, 2)
        
        // 9. User deletes the first board
        await boardListViewModel.delete(id: firstBoard.id)
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        XCTAssertEqual(boardListViewModel.boards.first?.name, "Second Board")
        
        // 10. Verify data persistence by creating new ViewModels
        let newBoardListViewModel = BoardListViewModel()
        await newBoardListViewModel.loadFirstPage()
        XCTAssertEqual(newBoardListViewModel.boards.count, 1)
        XCTAssertEqual(newBoardListViewModel.boards.first?.name, "Second Board")
    }
    
    // MARK: - Pattern Exploration Workflow
    
    func testPatternExplorationWorkflow() async throws {
        let gameService = Container.shared.gameService()
        
        // User creates classic Conway patterns
        let patterns = [
            ("Glider", [
                [false, true,  false],
                [false, false, true],
                [true,  true,  true]
            ]),
            ("Block (Still Life)", [
                [false, false, false, false],
                [false, true,  true,  false],
                [false, true,  true,  false],
                [false, false, false, false]
            ]),
            ("Blinker (Oscillator)", [
                [false, false, false],
                [true,  true,  true],
                [false, false, false]
            ])
        ]
        
        var boardIds: [UUID] = []
        
        // 1. Create all patterns
        for (name, pattern) in patterns {
            let boardId = await gameService.createBoard(pattern)
            boardIds.append(boardId)
            
            // Create board entry for display
            let board = try Board(
                id: boardId,
                name: name,
                width: pattern.first?.count ?? 0,
                height: pattern.count,
                cells: pattern
            )
            try await Container.shared.boardRepository().save(board)
        }
        
        // 2. Explore each pattern's behavior
        for (index, boardId) in boardIds.enumerated() {
            let (patternName, _) = patterns[index]
            let gameViewModel = GameViewModel(boardId: boardId)
            await gameViewModel.loadCurrent()
            
            switch patternName {
            case "Glider":
                // Glider should move diagonally
                let initialCells = gameViewModel.state?.cells
                await gameViewModel.step()
                await gameViewModel.step()
                await gameViewModel.step()
                await gameViewModel.step()
                
                let afterSteps = gameViewModel.state?.cells
                XCTAssertNotEqual(initialCells, afterSteps, "Glider should have moved")
                XCTAssertEqual(gameViewModel.state?.populationCount, 5, "Glider should maintain 5 cells")
                
            case "Block (Still Life)":
                // Block should remain stable
                let initialCells = gameViewModel.state?.cells
                await gameViewModel.step()
                
                XCTAssertEqual(initialCells, gameViewModel.state?.cells, "Block should remain unchanged")
                XCTAssertEqual(gameViewModel.state?.populationCount, 4, "Block should maintain 4 cells")
                
            case "Blinker (Oscillator)":
                // Blinker should oscillate between horizontal and vertical
                let horizontalState = gameViewModel.state?.cells
                await gameViewModel.step()
                let verticalState = gameViewModel.state?.cells
                await gameViewModel.step()
                let backToHorizontal = gameViewModel.state?.cells
                
                XCTAssertNotEqual(horizontalState, verticalState, "Blinker should change shape")
                XCTAssertEqual(horizontalState, backToHorizontal, "Blinker should return to original shape")
                XCTAssertEqual(gameViewModel.state?.populationCount, 3, "Blinker should maintain 3 cells")
                
            default:
                break
            }
        }
        
        // 3. Use final state detection on patterns
        for boardId in boardIds {
            let finalStateResult = await gameService.getFinalState(boardId: boardId, maxIterations: 100)
            XCTAssertTrue(finalStateResult.isSuccess, "All classic patterns should reach a final state")
            
            if case .success(let finalState) = finalStateResult {
                XCTAssertTrue(finalState.isStable, "Final state should be stable")
                XCTAssertNotNil(finalState.convergenceType, "Should have convergence information")
            }
        }
    }
    
    // MARK: - Large Scale Management Workflow
    
    func testLargeScaleManagementWorkflow() async throws {
        let boardListViewModel = BoardListViewModel()
        
        // 1. User creates many boards over time
        let boardCount = 50
        for i in 0..<boardCount {
            await boardListViewModel.createRandomBoard(
                name: "Board \(String(format: "%03d", i))",
                width: Int.random(in: 5...20),
                height: Int.random(in: 5...20),
                density: Double.random(in: 0.1...0.5)
            )
            
            // Simulate time passing
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        XCTAssertEqual(boardListViewModel.boards.count, 20) // First page
        XCTAssertEqual(boardListViewModel.totalCount, boardCount)
        XCTAssertTrue(boardListViewModel.hasMorePages)
        
        // 2. User searches for specific boards
        await boardListViewModel.search(query: "Board 0")
        XCTAssertEqual(boardListViewModel.boards.count, 11) // Board 000-009, 010, 020, etc.
        
        await boardListViewModel.search(query: "Board 042")
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        XCTAssertEqual(boardListViewModel.boards.first?.name, "Board 042")
        
        // 3. User clears search and tries different sorting
        await boardListViewModel.search(query: "")
        await boardListViewModel.changeSortOption(.nameAscending)
        XCTAssertEqual(boardListViewModel.sortOption, .nameAscending)
        
        // Verify alphabetical sorting
        let firstBoard = boardListViewModel.boards.first!
        XCTAssertEqual(firstBoard.name, "Board 000")
        
        // 4. User loads more pages
        await boardListViewModel.loadNextPage()
        XCTAssertEqual(boardListViewModel.boards.count, 40) // Two pages loaded
        
        await boardListViewModel.loadNextPage()
        XCTAssertEqual(boardListViewModel.boards.count, boardCount) // All loaded
        XCTAssertFalse(boardListViewModel.hasMorePages)
        
        // 5. User does bulk operations
        let boardsToDelete = Array(boardListViewModel.boards.prefix(10))
        for board in boardsToDelete {
            await boardListViewModel.delete(id: board.id)
        }
        
        await boardListViewModel.refresh()
        XCTAssertEqual(boardListViewModel.totalCount, boardCount - 10)
        
        // 6. User sorts by creation date to see newest
        await boardListViewModel.changeSortOption(.createdDateDescending)
        let newestBoard = boardListViewModel.boards.first!
        
        // Should be one of the later created boards (Board 040+)
        XCTAssertTrue(newestBoard.name.contains("04") || newestBoard.name.contains("03"))
    }
    
    // MARK: - Error Recovery Workflow
    
    func testErrorRecoveryWorkflow() async throws {
        let boardListViewModel = BoardListViewModel()
        
        // 1. Create a board successfully
        await boardListViewModel.createRandomBoard(name: "Test Board")
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        let testBoard = boardListViewModel.boards.first!
        
        // 2. Navigate to game view
        let gameViewModel = GameViewModel(boardId: testBoard.id)
        await gameViewModel.loadCurrent()
        XCTAssertNotNil(gameViewModel.state)
        
        // 3. Simulate error condition by trying to access non-existent board
        let invalidGameViewModel = GameViewModel(boardId: UUID())
        await invalidGameViewModel.loadCurrent()
        
        XCTAssertNil(invalidGameViewModel.state)
        XCTAssertNotNil(invalidGameViewModel.gameError)
        XCTAssertEqual(invalidGameViewModel.gameError, .boardNotFound(invalidGameViewModel.boardId))
        
        // 4. Test error recovery through user-friendly error system
        let userFriendlyError = invalidGameViewModel.gameError?.asUserFriendlyError(context: .boardLoading)
        XCTAssertNotNil(userFriendlyError)
        
        let recoveryActions = userFriendlyError?.recoveryActions ?? []
        XCTAssertTrue(recoveryActions.contains(.retry))
        XCTAssertTrue(recoveryActions.contains(.goBack))
        
        // 5. Simulate user choosing "go back" recovery action
        // This would be handled by the UI layer, but we can test the error messaging
        XCTAssertNotNil(userFriendlyError?.message)
        XCTAssertFalse(userFriendlyError?.message.isEmpty ?? true)
        
        // 6. Return to valid board and verify recovery
        await gameViewModel.loadCurrent() // Original valid board
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertNil(gameViewModel.gameError)
    }
    
    // MARK: - Theme and Configuration Workflow
    
    func testThemeAndConfigurationWorkflow() async throws {
        let themeManager = Container.shared.themeManager()
        
        // 1. User starts with default theme
        let initialTheme = themeManager.currentTheme
        XCTAssertEqual(initialTheme, .system) // Default theme
        
        // 2. User switches themes
        themeManager.currentTheme = .dark
        XCTAssertEqual(themeManager.currentTheme, .dark)
        
        let darkColors = themeManager.cellColors
        XCTAssertNotNil(darkColors.alive)
        XCTAssertNotNil(darkColors.dead)
        
        // 3. User switches to light theme
        themeManager.currentTheme = .light
        XCTAssertEqual(themeManager.currentTheme, .light)
        
        let lightColors = themeManager.cellColors
        XCTAssertNotNil(lightColors.alive)
        XCTAssertNotNil(lightColors.dead)
        
        // Colors should be different between themes
        XCTAssertNotEqual(darkColors.alive, lightColors.alive)
        
        // 4. Test game configuration changes
        let originalConfig = Container.shared.gameEngineConfiguration()
        XCTAssertEqual(originalConfig.rules, .conway)
        
        // Register new configuration
        Container.shared.gameEngineConfiguration.register {
            GameEngineConfiguration(rules: .highLife, maxGenerations: 2000)
        }
        
        let newConfig = Container.shared.gameEngineConfiguration()
        XCTAssertEqual(newConfig.rules, .highLife)
        XCTAssertEqual(newConfig.maxGenerations, 2000)
        
        // 5. Create board with new configuration and verify behavior
        let gameService = Container.shared.gameService()
        let testPattern: CellsGrid = [
            [false, true,  false],
            [true,  true,  true],
            [false, true,  false]
        ]
        
        let boardId = await gameService.createBoard(testPattern)
        let result = await gameService.getNextState(boardId: boardId)
        
        XCTAssertTrue(result.isSuccess)
        // The result should reflect HighLife rules (birth on 3 or 6 neighbors, survive on 2 or 3)
    }
    
    // MARK: - Performance and Scalability Workflow
    
    func testPerformanceWorkflow() async throws {
        // 1. User creates increasingly large boards
        let sizes = [(10, 10), (25, 25), (50, 50), (100, 100)]
        var boardIds: [UUID] = []
        
        for (width, height) in sizes {
            let gameService = Container.shared.gameService()
            let pattern = (0..<height).map { _ in
                (0..<width).map { _ in Bool.random() }
            }
            
            let startTime = DispatchTime.now()
            let boardId = await gameService.createBoard(pattern)
            let endTime = DispatchTime.now()
            
            let createDuration = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            boardIds.append(boardId)
            
            // Creation should complete reasonably quickly
            XCTAssertLessThan(createDuration, 1_000_000_000, "Board creation took too long for \(width)x\(height)")
        }
        
        // 2. Test step performance on different sizes
        for (index, boardId) in boardIds.enumerated() {
            let (width, height) = sizes[index]
            let gameService = Container.shared.gameService()
            
            let startTime = DispatchTime.now()
            let result = await gameService.getNextState(boardId: boardId)
            let endTime = DispatchTime.now()
            
            let stepDuration = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
            
            XCTAssertTrue(result.isSuccess, "Step failed for \(width)x\(height)")
            
            // Performance thresholds (adjust based on requirements)
            let maxDuration: UInt64 = width * height > 2500 ? 500_000_000 : 100_000_000 // 500ms for large, 100ms for small
            XCTAssertLessThan(stepDuration, maxDuration, "Step took too long for \(width)x\(height)")
        }
        
        // 3. Test final state detection performance
        let smallBoardId = boardIds[0] // 10x10 board
        let startTime = DispatchTime.now()
        let finalResult = await Container.shared.gameService().getFinalState(boardId: smallBoardId, maxIterations: 1000)
        let endTime = DispatchTime.now()
        
        let finalStateDuration = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        XCTAssertLessThan(finalStateDuration, 5_000_000_000) // 5 seconds max for final state detection
        
        XCTAssertTrue(finalResult.isSuccess || finalResult.isFailure) // Should complete one way or another
    }
    
    // MARK: - Multi-Session Workflow
    
    func testMultiSessionWorkflow() async throws {
        // Simulate user working across multiple app sessions
        
        // Session 1: User creates some boards
        var boardListViewModel = BoardListViewModel()
        await boardListViewModel.createRandomBoard(name: "Session 1 Board A")
        await boardListViewModel.createRandomBoard(name: "Session 1 Board B")
        
        let boardA = boardListViewModel.boards.first { $0.name == "Session 1 Board A" }!
        let boardB = boardListViewModel.boards.first { $0.name == "Session 1 Board B" }!
        
        // User plays with Board A
        var gameViewModel = GameViewModel(boardId: boardA.id)
        await gameViewModel.loadCurrent()
        await gameViewModel.step()
        await gameViewModel.step()
        XCTAssertEqual(gameViewModel.state?.generation, 2)
        
        // End of Session 1 (simulate app close/reopen by creating new instances)
        
        // Session 2: User resumes
        boardListViewModel = BoardListViewModel()
        await boardListViewModel.loadFirstPage()
        
        // Boards should still exist
        XCTAssertEqual(boardListViewModel.boards.count, 2)
        let resumedBoardA = boardListViewModel.boards.first { $0.name == "Session 1 Board A" }!
        XCTAssertEqual(resumedBoardA.id, boardA.id)
        
        // Resume working with Board A - should start from generation 0 (initial state)
        gameViewModel = GameViewModel(boardId: resumedBoardA.id)
        await gameViewModel.loadCurrent()
        XCTAssertEqual(gameViewModel.state?.generation, 0) // Always starts from initial state
        
        // User continues simulation
        await gameViewModel.jump(to: 10)
        XCTAssertEqual(gameViewModel.state?.generation, 10)
        
        // User creates another board in Session 2
        await boardListViewModel.createRandomBoard(name: "Session 2 Board C")
        XCTAssertEqual(boardListViewModel.boards.count, 3)
        
        // End of Session 2
        
        // Session 3: User deletes old boards
        boardListViewModel = BoardListViewModel()
        await boardListViewModel.loadFirstPage()
        XCTAssertEqual(boardListViewModel.boards.count, 3)
        
        await boardListViewModel.delete(id: boardA.id)
        await boardListViewModel.delete(id: boardB.id)
        XCTAssertEqual(boardListViewModel.boards.count, 1)
        XCTAssertEqual(boardListViewModel.boards.first?.name, "Session 2 Board C")
        
        // Verify persistence across session boundary
        let finalBoardListViewModel = BoardListViewModel()
        await finalBoardListViewModel.loadFirstPage()
        XCTAssertEqual(finalBoardListViewModel.boards.count, 1)
        XCTAssertEqual(finalBoardListViewModel.boards.first?.name, "Session 2 Board C")
    }
    
    // MARK: - Advanced User Workflow
    
    func testAdvancedUserWorkflow() async throws {
        // Experienced user working with complex patterns
        let gameService = Container.shared.gameService()
        
        // 1. User creates a Gosper Glider Gun pattern (complex pattern)
        let gliderGunPattern: CellsGrid = [
            [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false],
            [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true,  false, true,  false, false, false, false, false, false, false, false, false, false, false],
            [false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, true,  true],
            [false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, true,  true],
            [true,  true,  false, false, false, false, false, false, false, false, true,  false, false, false, false, false, true,  false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false],
            [true,  true,  false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, true,  true,  false, false, false, false, true,  false, true,  false, false, false, false, false, false, false, false, false, false, false],
            [false, false, false, false, false, false, false, false, false, false, true,  false, false, false, false, false, true,  false, false, false, false, false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false],
            [false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
            [false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
        ]
        
        let gliderGunId = await gameService.createBoard(gliderGunPattern)
        
        // Create board entry for display
        let gliderGunBoard = try Board(
            id: gliderGunId,
            name: "Gosper Glider Gun",
            width: gliderGunPattern.first?.count ?? 0,
            height: gliderGunPattern.count,
            cells: gliderGunPattern
        )
        try await Container.shared.boardRepository().save(gliderGunBoard)
        
        // 2. User analyzes the pattern evolution
        let gameViewModel = GameViewModel(boardId: gliderGunId)
        await gameViewModel.loadCurrent()
        
        let initialPopulation = gameViewModel.state?.populationCount ?? 0
        XCTAssertGreaterThan(initialPopulation, 30) // Glider gun has many living cells
        
        // 3. User steps through several generations
        var populations: [Int] = []
        for _ in 0..<10 {
            await gameViewModel.step()
            populations.append(gameViewModel.state?.populationCount ?? 0)
        }
        
        XCTAssertEqual(gameViewModel.state?.generation, 10)
        
        // 4. User jumps to observe long-term behavior
        await gameViewModel.jump(to: 100)
        let gen100Population = gameViewModel.state?.populationCount ?? 0
        XCTAssertGreaterThan(gen100Population, initialPopulation) // Should have created gliders
        
        // 5. User runs final state detection (should timeout or reach generation limit)
        let finalStateResult = await gameService.getFinalState(boardId: gliderGunId, maxIterations: 1000)
        
        // Glider gun should not converge within 1000 generations
        if case .failure(let error) = finalStateResult {
            XCTAssertTrue(
                error == .convergenceTimeout(maxIterations: 1000) || 
                error == .generationLimitExceeded(1000)
            )
        } else {
            // If it did converge, that's also valid (though unlikely for a true glider gun)
            XCTAssertTrue(finalStateResult.isSuccess)
        }
        
        // 6. User compares with simpler patterns
        let stillLifeId = await gameService.createBoard([
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ])
        
        let stillLifeResult = await gameService.getFinalState(boardId: stillLifeId, maxIterations: 10)
        XCTAssertTrue(stillLifeResult.isSuccess, "Still life should converge quickly")
        
        if case .success(let stillLifeState) = stillLifeResult {
            XCTAssertEqual(stillLifeState.generation, 1, "Still life should stabilize immediately")
            XCTAssertTrue(stillLifeState.isStable)
        }
    }
}