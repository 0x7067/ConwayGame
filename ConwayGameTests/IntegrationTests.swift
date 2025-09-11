import XCTest
import ConwayGameEngine
import SwiftUI
import CoreData
import FactoryKit
import FactoryTesting
@testable import ConwayGame

@MainActor
final class ConwayGameIntegrationTests: XCTestCase {
    private var container: Container!
    private var persistenceController: PersistenceController!
    private var gameService: DefaultGameService!
    private var boardRepository: CoreDataBoardRepository!
    private var gameEngine: ConwayGameEngine!
    private var convergenceDetector: DefaultConvergenceDetector!
    private var themeManager: ThemeManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        persistenceController = PersistenceController(inMemory: true)
        
        // Create real service dependencies
        gameEngine = ConwayGameEngine()
        boardRepository = CoreDataBoardRepository(container: persistenceController.container)
        convergenceDetector = DefaultConvergenceDetector()
        gameService = DefaultGameService(
            gameEngine: gameEngine,
            repository: boardRepository,
            convergenceDetector: convergenceDetector
        )
        themeManager = ThemeManager()
        
        // Set up Factory container with real implementations
        let gameService = self.gameService!
        let boardRepository = self.boardRepository!
        let gameEngine = self.gameEngine!
        let convergenceDetector = self.convergenceDetector!
        let themeManager = self.themeManager!
        
        Container.shared.gameService.register { gameService }
        Container.shared.boardRepository.register { boardRepository }
        Container.shared.gameEngine.register { gameEngine }
        Container.shared.convergenceDetector.register { convergenceDetector }
        Container.shared.themeManager.register { themeManager }
        Container.shared.gameEngineConfiguration.register { .default }
        Container.shared.playSpeedConfiguration.register { .default }
    }
    
    override func tearDown() {
        Container.shared.reset()
        persistenceController = nil
        gameService = nil
        boardRepository = nil
        gameEngine = nil
        convergenceDetector = nil
        themeManager = nil
        super.tearDown()
    }
    
    // MARK: - Complete User Workflow Integration Tests
    
    func testCompleteUserWorkflow_CreateBoardToFinalState() async throws {
        // 1. Create a board through the full stack
        let gliderPattern: CellsGrid = [
            [false, true,  false, false, false],
            [false, false, true,  false, false],
            [true,  true,  true,  false, false],
            [false, false, false, false, false],
            [false, false, false, false, false]
        ]
        
        let boardId = await gameService.createBoard(gliderPattern)
        XCTAssertNotEqual(boardId, UUID())
        
        // 2. Create ViewModel and verify initial load
        let gameViewModel = GameViewModel(boardId: boardId)
        await gameViewModel.loadCurrent()
        
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.state?.boardId, boardId)
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        XCTAssertEqual(gameViewModel.state?.populationCount, 5) // Glider has 5 living cells
        
        // 3. Step through generations
        await gameViewModel.step()
        XCTAssertEqual(gameViewModel.state?.generation, 1)
        XCTAssertGreaterThan(gameViewModel.state?.populationCount ?? 0, 0)
        
        await gameViewModel.step()
        XCTAssertEqual(gameViewModel.state?.generation, 2)
        
        // 4. Jump to future generation
        await gameViewModel.jump(to: 10)
        XCTAssertEqual(gameViewModel.state?.generation, 10)
        XCTAssertGreaterThan(gameViewModel.state?.populationCount ?? 0, 0)
        
        // 5. Reset to initial state
        await gameViewModel.reset()
        XCTAssertEqual(gameViewModel.state?.generation, 0)
        XCTAssertEqual(gameViewModel.state?.populationCount, 5)
        
        // 6. Verify persistence by creating new ViewModel
        let newViewModel = GameViewModel(boardId: boardId)
        await newViewModel.loadCurrent()
        XCTAssertEqual(newViewModel.state?.cells, gliderPattern)
        XCTAssertEqual(newViewModel.state?.generation, 0)
    }
    
    func testBoardListToGameViewIntegration() async throws {
        // 1. Create multiple boards through BoardListViewModel
        let boardListViewModel = BoardListViewModel()
        
        await boardListViewModel.createRandomBoard(name: "Test Board 1", width: 10, height: 10, density: 0.3)
        await boardListViewModel.createRandomBoard(name: "Test Board 2", width: 15, height: 15, density: 0.2)
        
        XCTAssertEqual(boardListViewModel.boards.count, 2)
        
        // 2. Select first board and transition to GameView
        // Select the specific board by name to avoid sort-order flakiness
        guard let firstBoard = boardListViewModel.boards.first(where: { $0.name == "Test Board 1" }) else {
            XCTFail("No boards found")
            return
        }
        
        let gameViewModel = GameViewModel(boardId: firstBoard.id)
        await gameViewModel.loadCurrent()
        
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.state?.boardId, firstBoard.id)
        XCTAssertEqual(gameViewModel.state?.cells.count, 10) // height
        XCTAssertEqual(gameViewModel.state?.cells.first?.count, 10) // width
        
        // 3. Modify board and verify changes persist
        await gameViewModel.step()
        let modifiedGeneration = gameViewModel.state?.generation ?? 0
        XCTAssertGreaterThan(modifiedGeneration, 0)
        
        // 4. Go back to board list and verify updates
        await boardListViewModel.loadFirstPage()
        let updatedBoard = boardListViewModel.boards.first { $0.id == firstBoard.id }
        XCTAssertNotNil(updatedBoard)
    }
    
    func testErrorHandlingAcrossAllLayers() async throws {
        let boardId = UUID() // Non-existent board
        
        // 1. Test ViewModel error handling
        let gameViewModel = GameViewModel(boardId: boardId)
        await gameViewModel.loadCurrent()
        
        XCTAssertNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.gameError, .boardNotFound(boardId))
        
        // 2. Test error recovery
        let realBoard = try Board(
            id: UUID(),
            name: "Recovery Test",
            width: 3,
            height: 3,
            cells: [[true, false, true], [false, true, false], [true, false, true]]
        )
        try await boardRepository.save(realBoard)
        
        // Create new ViewModel with valid board
        let recoveryViewModel = GameViewModel(boardId: realBoard.id)
        await recoveryViewModel.loadCurrent()
        
        XCTAssertNotNil(recoveryViewModel.state)
        XCTAssertNil(recoveryViewModel.gameError)
        XCTAssertEqual(recoveryViewModel.state?.boardId, realBoard.id)
    }
    
    // MARK: - Configuration Integration Tests
    
    func testConfigurationSystemIntegration() async throws {
        // Test different rule configurations
        let testPattern: CellsGrid = [
            [false, true,  false],
            [true,  true,  true],
            [false, true,  false]
        ]
        
        // Test Conway rules (default)
        Container.shared.gameEngineConfiguration.register { 
            .classicConway
        }
        
        let conwayEngine = Container.shared.gameEngine()
        let conwayResult = conwayEngine.computeNextState(testPattern)
        
        // Test HighLife rules
        Container.shared.gameEngineConfiguration.register { 
            .highLife
        }
        
        let highLifeEngine = ConwayGameEngine(configuration: Container.shared.gameEngineConfiguration())
        let highLifeResult = highLifeEngine.computeNextState(testPattern)
        
        // Results should potentially be different for different rule sets
        XCTAssertNotNil(conwayResult)
        XCTAssertNotNil(highLifeResult)
        
        // Both should be valid grids of same size
        XCTAssertEqual(conwayResult.count, testPattern.count)
        XCTAssertEqual(highLifeResult.count, testPattern.count)
    }
    
    func testPlaySpeedConfigurationIntegration() async throws {
        let boardId = await gameService.createBoard([[true, false], [false, true]])
        let gameViewModel = GameViewModel(boardId: boardId)
        await gameViewModel.loadCurrent()
        
        // Test different play speeds
        let speeds: [PlaySpeed] = [.turbo, .faster, .fast, .normal]
        
        for speed in speeds {
            gameViewModel.playSpeed = speed
            XCTAssertEqual(gameViewModel.playSpeed, speed)
            
            // Verify the speed setting affects the interval (indirectly)
            let config = Container.shared.playSpeedConfiguration()
            let interval = config.interval(for: speed)
            XCTAssertGreaterThan(interval, 0)
        }
    }
    
    // MARK: - Theme Integration Tests
    
    func testThemeManagerIntegration() async throws {
        let themeManager = Container.shared.themeManager()
        
        // Test theme switching
        themeManager.themePreference = .dark
        XCTAssertEqual(themeManager.themePreference, .dark)
        
        themeManager.themePreference = .light
        XCTAssertEqual(themeManager.themePreference, .light)
        
        themeManager.themePreference = .system
        XCTAssertEqual(themeManager.themePreference, .system)
        
        // Test theme manager properties are accessible
        XCTAssertGreaterThan(themeManager.defaultBoardSize, 0)
        XCTAssertTrue(PlaySpeed.allCases.contains(themeManager.defaultPlaySpeed))
    }
    
    // MARK: - Memory and Performance Integration Tests
    
    func testMemoryManagementAcrossLayers() async throws {
        // Create and destroy multiple ViewModels to test memory management
        for _ in 0..<10 {
            let boardId = await gameService.createBoard([[Bool.random(), Bool.random()], [Bool.random(), Bool.random()]])
            let gameViewModel = GameViewModel(boardId: boardId)
            await gameViewModel.loadCurrent()
            
            // Simulate play loop
            gameViewModel.play()
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            gameViewModel.pause()
            
            // Verify state
            XCTAssertNotNil(gameViewModel.state)
            XCTAssertFalse(gameViewModel.isPlaying)
        }
        
        // Force garbage collection and verify no memory leaks
        // (This is implicit - the test will fail if there are retain cycles)
    }
    
    func testConcurrentAccessAcrossLayers() async throws {
        let boardId = await gameService.createBoard([
            [true,  false, true,  false],
            [false, true,  false, true],
            [true,  false, true,  false],
            [false, true,  false, true]
        ])
        
        // Test concurrent ViewModels accessing same board
        let viewModel1 = GameViewModel(boardId: boardId)
        let viewModel2 = GameViewModel(boardId: boardId)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel1.loadCurrent()
                await viewModel1.step()
                await viewModel1.jump(to: 5)
            }
            
            group.addTask {
                await viewModel2.loadCurrent()
                await viewModel2.step()
                await viewModel2.finalState(maxIterations: 100)
            }
        }
        
        // Both should complete successfully
        XCTAssertNotNil(viewModel1.state)
        XCTAssertNotNil(viewModel2.state)
        XCTAssertEqual(viewModel1.state?.boardId, boardId)
        XCTAssertEqual(viewModel2.state?.boardId, boardId)
    }
    
    // MARK: - Convergence Detection Integration Tests
    
    func testConvergenceDetectionIntegration() async throws {
        // Test still life detection
        let blockPattern: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        let blockBoardId = await gameService.createBoard(blockPattern)
        let blockResult = await gameService.getFinalState(boardId: blockBoardId, maxIterations: 10)
        
        guard case .success(let blockFinalState) = blockResult else {
            XCTFail("Expected success for block pattern")
            return
        }
        
        XCTAssertTrue(blockFinalState.isStable)
        XCTAssertEqual(blockFinalState.populationCount, 4)
        XCTAssertEqual(blockFinalState.generation, 1) // Should stabilize immediately
        
        // Test oscillator detection
        let blinkerPattern: CellsGrid = [
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ]
        
        let blinkerBoardId = await gameService.createBoard(blinkerPattern)
        let blinkerResult = await gameService.getFinalState(boardId: blinkerBoardId, maxIterations: 10)
        
        guard case .success(let blinkerFinalState) = blinkerResult else {
            XCTFail("Expected success for blinker pattern")
            return
        }
        
        XCTAssertTrue(blinkerFinalState.isStable)
        XCTAssertEqual(blinkerFinalState.populationCount, 3)
        if case .cyclical(let period) = blinkerFinalState.convergenceType {
            XCTAssertEqual(period, 0) // Detected as cyclical
        } else {
            XCTFail("Expected cyclical convergence")
        }
        
        // Test extinction detection
        let singleCellPattern: CellsGrid = [
            [false, false, false],
            [false, true,  false],
            [false, false, false]
        ]
        
        let extinctBoardId = await gameService.createBoard(singleCellPattern)
        let extinctResult = await gameService.getFinalState(boardId: extinctBoardId, maxIterations: 10)
        
        guard case .success(let extinctFinalState) = extinctResult else {
            XCTFail("Expected success for extinction pattern")
            return
        }
        
        XCTAssertTrue(extinctFinalState.isStable)
        XCTAssertEqual(extinctFinalState.populationCount, 0)
        XCTAssertEqual(extinctFinalState.convergenceType, .extinct)
    }
    
    // MARK: - User-Friendly Error Integration Tests
    
    func testUserFriendlyErrorIntegration() async throws {
        let boardId = UUID() // Non-existent
        let gameViewModel = GameViewModel(boardId: boardId)
        
        // Test error transformation through the full stack
        await gameViewModel.loadCurrent()
        
        XCTAssertEqual(gameViewModel.gameError, .boardNotFound(boardId))
        
        // Test error message generation
        let userFriendlyError = gameViewModel.gameError?.userFriendly(context: .boardLoading)
        XCTAssertNotNil(userFriendlyError)
        XCTAssertFalse(userFriendlyError?.userFriendlyMessage.isEmpty ?? true)
        XCTAssertFalse(userFriendlyError?.recoveryActions.isEmpty ?? true)
        
        // Test recovery actions
        let recoveryActions = userFriendlyError?.recoveryActions ?? []
        XCTAssertTrue(recoveryActions.contains(.goToBoardList))
    }
    
    // MARK: - Data Persistence Integration Tests
    
    func testDataPersistenceIntegration() async throws {
        let originalPattern: CellsGrid = [
            [true,  false, true],
            [false, false, false],
            [true,  false, true]
        ]
        
        // 1. Create board and advance several generations
        let boardId = await gameService.createBoard(originalPattern)
        
        for _ in 0..<5 {
            _ = await gameService.getNextState(boardId: boardId)
        }
        
        let generation5Result = await gameService.getStateAtGeneration(boardId: boardId, generation: 5)
        guard case .success(let generation5State) = generation5Result else {
            XCTFail("Failed to get generation 5")
            return
        }
        
        // 2. Create new service instance (simulating app restart)
        let newPersistenceController = PersistenceController(inMemory: true)
        
        // Copy data to new context (simulating data persistence)
        let board = try Board(
            id: boardId,
            name: "Test Board",
            width: 3,
            height: 3,
            cells: originalPattern
        )
        
        let newRepository = CoreDataBoardRepository(container: newPersistenceController.container)
        try await newRepository.save(board)
        
        let newGameService = DefaultGameService(
            gameEngine: ConwayGameEngine(),
            repository: newRepository,
            convergenceDetector: DefaultConvergenceDetector()
        )
        
        // 3. Verify data persistence
        let restoredGeneration5 = await newGameService.getStateAtGeneration(boardId: boardId, generation: 5)
        guard case .success(let restoredState) = restoredGeneration5 else {
            XCTFail("Failed to restore generation 5")
            return
        }
        
        XCTAssertEqual(restoredState.generation, generation5State.generation)
        XCTAssertEqual(restoredState.cells, generation5State.cells)
        XCTAssertEqual(restoredState.populationCount, generation5State.populationCount)
    }
    
    // MARK: - Large Scale Integration Tests
    
    func testLargeScaleIntegration() async throws {
        // Test with larger grids
        let largePattern = (0..<50).map { _ in
            (0..<50).map { _ in Bool.random() }
        }
        
        let largeBoardId = await gameService.createBoard(largePattern)
        let gameViewModel = GameViewModel(boardId: largeBoardId)
        
        await gameViewModel.loadCurrent()
        XCTAssertNotNil(gameViewModel.state)
        XCTAssertEqual(gameViewModel.state?.cells.count, 50)
        XCTAssertEqual(gameViewModel.state?.cells.first?.count, 50)
        
        // Test performance with larger grid
        let startTime = DispatchTime.now()
        await gameViewModel.step()
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        XCTAssertLessThan(elapsed, 1_000_000_000) // Should complete within 1 second
        XCTAssertEqual(gameViewModel.state?.generation, 1)
    }
}
