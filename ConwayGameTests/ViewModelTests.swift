import XCTest
import ConwayGameEngine
@testable import ConwayGame
import SwiftUI
import FactoryKit
import FactoryTesting

@MainActor
final class GameViewModelTests: XCTestCase {
    private var viewModel: GameViewModel!
    private var mockService: MockGameService!
    private var mockRepository: MockBoardRepository!
    private var testBoardId: UUID!
    private var themeManager: ThemeManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockService = MockGameService()
        mockRepository = MockBoardRepository()
        testBoardId = UUID()
        themeManager = ThemeManager()
        
        // Set up Factory test container with mocks
        let service = mockService!
        let repository = mockRepository!
        let theme = themeManager!
        
        Container.shared.gameService.register { service }
        Container.shared.boardRepository.register { repository }
        Container.shared.themeManager.register { theme }
        
        viewModel = GameViewModel(boardId: testBoardId)
    }
    
    override func tearDown() {
        viewModel = nil
        mockService = nil
        mockRepository = nil
        Container.shared.reset()
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func test_init_setsInitialState() {
        XCTAssertNil(viewModel.state)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
        XCTAssertFalse(viewModel.isFinalLocked)
    }
    
    // MARK: - LoadCurrent Tests
    
    func test_loadCurrent_success_updatesState() async {
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        
        await viewModel.loadCurrent()
        
        XCTAssertNotNil(viewModel.state)
        XCTAssertEqual(viewModel.state?.boardId, testBoardId)
        XCTAssertEqual(viewModel.state?.generation, 0)
        XCTAssertEqual(viewModel.state?.populationCount, 4)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
        XCTAssertFalse(viewModel.isFinalLocked)
    }
    
    func test_loadCurrent_boardNotFound_setsGameError() async {
        // Repository is empty, board won't be found
        await viewModel.loadCurrent()
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .boardNotFound(testBoardId))
    }
    
    func test_loadCurrent_repositoryError_setsGameError() async {
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .computationError("Repository error")
        
        await viewModel.loadCurrent()
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .computationError("Repository error"))
    }
    
    // MARK: - Step Tests
    
    func test_step_success_updatesState() async {
        let testState = createTestGameState()
        mockService.nextStateResult = .success(testState)
        
        await viewModel.step()
        
        XCTAssertEqual(viewModel.state, testState)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
        XCTAssertEqual(viewModel.state?.generation, testState.generation)
    }
    
    func test_step_failure_setsGameError() async {
        mockService.nextStateResult = .failure(.computationError("Step error"))
        
        await viewModel.step()
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .computationError("Step error"))
    }
    
    func test_step_whenFinalLocked_doesNothing() async {
        let initialState = viewModel.state
        viewModel.isFinalLocked = true
        
        await viewModel.step()
        
        XCTAssertEqual(viewModel.state, initialState)
        XCTAssertNil(viewModel.gameError)
    }
    
    // MARK: - Jump Tests
    
    func test_jump_success_updatesState() async {
        // Setup board in repository for the jump method to update
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        
        let targetGeneration = 10
        let testState = createTestGameState(generation: targetGeneration)
        mockService.stateAtGenerationResult = .success(testState)
        
        await viewModel.jump(to: targetGeneration)
        
        XCTAssertEqual(viewModel.state, testState)
        XCTAssertEqual(viewModel.state?.generation, targetGeneration)
        XCTAssertFalse(viewModel.isFinalLocked)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
    }
    
    func test_jump_failure_setsGameError() async {
        mockService.stateAtGenerationResult = .failure(.boardNotFound(testBoardId))
        
        await viewModel.jump(to: 5)
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .boardNotFound(testBoardId))
    }
    
    // MARK: - FinalState Tests
    
    func test_finalState_success_updatesStateAndPauses() async {
        let finalState = createTestGameState(isStable: true)
        mockService.finalStateResult = .success(finalState)
        
        viewModel.play() // Start playing first
        XCTAssertTrue(viewModel.isPlaying)
        
        await viewModel.finalState(maxIterations: 100)
        
        XCTAssertEqual(viewModel.state, finalState)
        XCTAssertTrue(viewModel.isFinalLocked)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
    }
    
    func test_finalState_failure_setsGameError() async {
        mockService.finalStateResult = .failure(.convergenceTimeout(maxIterations: 100))
        
        await viewModel.finalState(maxIterations: 100)
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .convergenceTimeout(maxIterations: 100))
        XCTAssertFalse(viewModel.isFinalLocked)
    }
    
    func test_finalState_generationLimitExceeded_showsGenerationLimitAlert() async {
        mockService.finalStateResult = .failure(.generationLimitExceeded(500))
        
        await viewModel.finalState(maxIterations: 500)
        
        XCTAssertNil(viewModel.state)
        XCTAssertTrue(viewModel.showGenerationLimitAlert)
        XCTAssertNil(viewModel.errorMessage) // Should not set error message
        XCTAssertNil(viewModel.gameError) // Should not set game error either
        XCTAssertFalse(viewModel.isFinalLocked)
    }
    
    func test_finalState_generationLimitExceeded_doesNotSetErrorMessage() async {
        mockService.finalStateResult = .failure(.generationLimitExceeded(500))
        
        await viewModel.finalState(maxIterations: 500)
        
        XCTAssertTrue(viewModel.showGenerationLimitAlert)
        XCTAssertNil(viewModel.errorMessage) // Should be nil, not the generic error message
        XCTAssertNil(viewModel.gameError) // Should not set game error
    }
    
    func test_showGenerationLimitAlert_initiallyFalse() {
        XCTAssertFalse(viewModel.showGenerationLimitAlert)
    }
    
    func test_finalState_convergenceInfo_isPreserved() async {
        // Test that convergence info is preserved when final state succeeds
        let convergentState = GameState(
            boardId: testBoardId,
            generation: 5,
            cells: [[false, false], [false, false]],
            isStable: true,
            populationCount: 0,
            convergedAt: 5,
            convergenceType: .extinct
        )
        mockService.finalStateResult = .success(convergentState)
        
        await viewModel.finalState(maxIterations: 100)
        
        XCTAssertEqual(viewModel.state, convergentState)
        XCTAssertEqual(viewModel.state?.convergedAt, 5)
        XCTAssertEqual(viewModel.state?.convergenceType, .extinct)
        XCTAssertTrue(viewModel.isFinalLocked)
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    // MARK: - Reset Tests
    
    func test_reset_success_resetsToInitialState() async {
        let resetBoard = createTestBoard()
        mockRepository.preloadBoard(resetBoard)
        
        viewModel.play() // Start playing first
        viewModel.isFinalLocked = true // Lock it
        
        await viewModel.reset()
        
        XCTAssertNotNil(viewModel.state)
        XCTAssertEqual(viewModel.state?.generation, 0)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertFalse(viewModel.isFinalLocked)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.gameError)
    }
    
    func test_reset_failure_setsGameError() async {
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .boardNotFound(testBoardId)
        
        await viewModel.reset()
        
        XCTAssertNil(viewModel.state)
        XCTAssertEqual(viewModel.gameError, .boardNotFound(testBoardId))
    }
    
    // MARK: - Play/Pause Tests
    
    func test_play_startsPlaying() {
        XCTAssertFalse(viewModel.isPlaying)
        
        viewModel.play()
        
        XCTAssertTrue(viewModel.isPlaying)
    }
    
    func test_play_whenAlreadyPlaying_doesNothing() {
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        
        let wasPlaying = viewModel.isPlaying
        viewModel.play()
        
        XCTAssertEqual(viewModel.isPlaying, wasPlaying)
    }
    
    func test_pause_stopsPlaying() {
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        
        viewModel.pause()
        
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    func test_pause_whenNotPlaying_doesNothing() {
        XCTAssertFalse(viewModel.isPlaying)
        
        viewModel.pause()
        
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    // MARK: - Play Loop Tests
    
    func test_playLoop_stepsAutomatically() async throws {
        let testState1 = createTestGameState(generation: 1)
        let testState2 = createTestGameState(generation: 2)
        
        mockService.nextStateResults = [.success(testState1), .success(testState2)]
        
        viewModel.play()
        
        // Give it time to execute a few steps
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        viewModel.pause()
        
        // Should have made some progress
        XCTAssertTrue(viewModel.state?.generation ?? 0 > 0)
    }
    
    func test_playLoop_stopsAtMaxSteps() async throws {
        // Use a smaller max steps count for testing (turbo = 62.5ms per step, so 20 steps = ~1.25 seconds)
        viewModel.maxAutoStepsPerRun = 20
        
        // Set up more than enough successful steps
        mockService.nextStateResults = Array(repeating: .success(createTestGameState()), count: 30)
        
        // Use turbo speed for faster testing
        viewModel.playSpeed = .turbo
        
        viewModel.play()
        
        // Wait longer than max steps should take (20 steps × 62.5ms = 1.25 seconds + buffer)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Should automatically pause due to max steps
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.state?.generation, 20) // Should have advanced exactly 20 generations
    }
    
    // MARK: - Play Speed Tests
    
    func test_playSpeed_normal_usesCorrectInterval() async throws {
        viewModel.playSpeed = .normal
        let testState = createTestGameState(generation: 1)
        mockService.nextStateResults = [.success(testState)]
        
        let startTime = DispatchTime.now()
        viewModel.play()
        
        // Wait for one step plus buffer
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        viewModel.pause()
        
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        XCTAssertTrue(viewModel.state?.generation ?? 0 > 0)
        XCTAssertGreaterThan(elapsed, 400_000_000) // Should take at least 0.4 seconds (normal = 0.5s)
    }
    
    func test_playSpeed_fast_usesCorrectInterval() async throws {
        viewModel.playSpeed = .fast
        let testState = createTestGameState(generation: 1)
        mockService.nextStateResults = [.success(testState)]
        
        let startTime = DispatchTime.now()
        viewModel.play()
        
        // Wait for one step plus buffer
        try await Task.sleep(nanoseconds: 350_000_000) // 0.35 seconds
        viewModel.pause()
        
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        XCTAssertTrue(viewModel.state?.generation ?? 0 > 0)
        XCTAssertGreaterThan(elapsed, 200_000_000) // Should take at least 0.2 seconds (fast = 0.25s)
    }
    
    func test_playSpeed_faster_usesCorrectInterval() async throws {
        viewModel.playSpeed = .faster
        let testState = createTestGameState(generation: 1)
        mockService.nextStateResults = [.success(testState)]
        
        let startTime = DispatchTime.now()
        viewModel.play()
        
        // Wait for one step plus buffer
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        viewModel.pause()
        
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        XCTAssertTrue(viewModel.state?.generation ?? 0 > 0)
        XCTAssertGreaterThan(elapsed, 100_000_000) // Should take at least 0.1 seconds (faster = 0.125s)
    }
    
    func test_playSpeed_turbo_usesCorrectInterval() async throws {
        viewModel.playSpeed = .turbo
        let testState1 = createTestGameState(generation: 1)
        let testState2 = createTestGameState(generation: 2)
        mockService.nextStateResults = [.success(testState1), .success(testState2)]
        
        let startTime = DispatchTime.now()
        viewModel.play()
        
        // Wait for two steps plus buffer
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        viewModel.pause()
        
        let endTime = DispatchTime.now()
        let elapsed = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        XCTAssertGreaterThan(viewModel.state?.generation ?? 0, 1) // Should complete multiple steps quickly
        XCTAssertLessThan(elapsed, 300_000_000) // Should complete in less than 0.3 seconds (turbo = 0.0625s per step)
    }
    
    func test_playSpeed_defaultIsNormal() {
        XCTAssertEqual(viewModel.playSpeed, .normal)
    }
    
    func test_playSpeed_canBeChanged() {
        XCTAssertEqual(viewModel.playSpeed, .normal)
        
        viewModel.playSpeed = .turbo
        XCTAssertEqual(viewModel.playSpeed, .turbo)
        
        viewModel.playSpeed = .fast
        XCTAssertEqual(viewModel.playSpeed, .fast)
    }

    // MARK: - Deinit Tests
    
    func test_deinit_cancelsPlayTask() {
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        
        // Simulate deinit by setting to nil
        viewModel = nil
        
        // Task should be cancelled (we can't directly test this, but it shouldn't crash)
    }
    
    // MARK: - Error Handling Tests
    
    func test_handleRecoveryAction_retry_reloadsBoard() async {
        // Setup initial board
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        
        viewModel.handleRecoveryAction(.retry)
        
        // Give async operation time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNotNil(viewModel.state) // Board should be loaded
    }
    
    func test_handleRecoveryAction_resetBoard_resetsBoard() async {
        // Setup initial board
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        
        viewModel.handleRecoveryAction(.resetBoard)
        
        // Give async operation time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(viewModel.state?.generation, 0) // Board should be reset
    }
    
    func test_handleRecoveryAction_tryAgain_performsStep() async {
        // Setup initial board and state
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        await viewModel.loadCurrent()
        
        let initialGeneration = viewModel.state?.generation ?? 0
        
        viewModel.handleRecoveryAction(.tryAgain)
        
        // Give async operation time to complete  
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(viewModel.state?.generation ?? 0, initialGeneration + 1)
    }
    
    func test_handleRecoveryAction_navigationActions_doNothing() {
        // These actions should be handled by the UI layer, not the ViewModel
        viewModel.handleRecoveryAction(.goBack)
        viewModel.handleRecoveryAction(.goToBoardList) 
        viewModel.handleRecoveryAction(.createNew)
        viewModel.handleRecoveryAction(.continueWithoutSaving)
        viewModel.handleRecoveryAction(.cancel)
        viewModel.handleRecoveryAction(.contactSupport)
        
        // No assertions needed - just ensuring no crashes occur
        XCTAssert(true)
    }
    
    func test_multipleErrors_onlyShowsLatest() async {
        mockService.nextStateResult = .failure(.computationError("First error"))
        await viewModel.step()
        XCTAssertEqual(viewModel.gameError, .computationError("First error"))
        
        mockService.stateAtGenerationResult = .failure(.boardNotFound(testBoardId))
        await viewModel.jump(to: 5)
        XCTAssertEqual(viewModel.gameError, .boardNotFound(testBoardId))
        XCTAssertNotEqual(viewModel.gameError, .computationError("First error"))
    }
    
    // MARK: - Concurrent Operations Tests
    
    func test_concurrentOperations_handledSafely() async {
        let testBoard = createTestBoard()
        mockRepository.preloadBoard(testBoard)
        mockService.nextStateResult = .success(createTestGameState())
        mockService.stateAtGenerationResult = .success(createTestGameState())
        mockService.finalStateResult = .success(createTestGameState())
        
        // Run multiple operations concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.viewModel.loadCurrent() }
            group.addTask { await self.viewModel.step() }
            group.addTask { await self.viewModel.jump(to: 10) }
            group.addTask { await self.viewModel.finalState(maxIterations: 50) }
            group.addTask { await self.viewModel.reset() }
        }
        
        // Should complete without crashing
        XCTAssertNotNil(viewModel.state)
    }
    
    // MARK: - Helper Methods
    
    private func createTestBoard() -> Board {
        let cells: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        return try! Board(
            id: testBoardId,
            name: "Test Board",
            width: 4,
            height: 4,
            cells: cells
        )
    }
    
    private func createTestGameState(
        generation: Int = 0,
        isStable: Bool = false,
        populationCount: Int = 4
    ) -> GameState {
        let cells: CellsGrid = [
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ]
        
        return GameState(
            boardId: testBoardId,
            generation: generation,
            cells: cells,
            isStable: isStable,
            populationCount: populationCount
        )
    }
}

// MARK: - BoardListViewModel Tests

@MainActor
final class BoardListViewModelTests: XCTestCase {
    private var viewModel: BoardListViewModel!
    private var mockService: MockGameService!
    private var mockRepository: MockBoardRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        mockService = MockGameService()
        mockRepository = MockBoardRepository()
        
        // Set up Factory test container with mocks
        let service = mockService!
        let repository = mockRepository!
        
        Container.shared.gameService.register { service }
        Container.shared.boardRepository.register { repository }
        Container.shared.gameEngineConfiguration.register { .default }
        
        viewModel = BoardListViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        mockService = nil
        mockRepository = nil
        Container.shared.reset()
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func test_init_setsInitialState() {
        XCTAssertTrue(viewModel.boards.isEmpty)
        XCTAssertNil(viewModel.gameError)
    }
    
    // MARK: - Load Tests
    
    func test_load_success_updatesBoards() async {
        let testBoards = [
            createTestBoard(name: "Board 1"),
            createTestBoard(name: "Board 2"), 
            createTestBoard(name: "Board 3")
        ]
        
        for board in testBoards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.load()
        
        XCTAssertEqual(viewModel.boards.count, 3)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_load_failure_clearsBoardsAndSetsError() async {
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .persistenceError("Load error")
        
        await viewModel.load()
        
        XCTAssertTrue(viewModel.boards.isEmpty)
        XCTAssertEqual(viewModel.gameError, .persistenceError("Load error"))
    }
    
    func test_load_sortsByCreatedDate() async {
        let now = Date()
        let board1 = createTestBoard(name: "Board 1", createdAt: now.addingTimeInterval(10))
        let board2 = createTestBoard(name: "Board 2", createdAt: now)
        let board3 = createTestBoard(name: "Board 3", createdAt: now.addingTimeInterval(5))
        
        mockRepository.preloadBoard(board1)
        mockRepository.preloadBoard(board2) 
        mockRepository.preloadBoard(board3)
        
        await viewModel.load()
        
        XCTAssertEqual(viewModel.boards.count, 3)
        XCTAssertEqual(viewModel.boards[0].name, "Board 1") // Latest
        XCTAssertEqual(viewModel.boards[1].name, "Board 3") // Middle
        XCTAssertEqual(viewModel.boards[2].name, "Board 2") // Earliest
    }
    
    // MARK: - Delete Tests
    
    func test_delete_success_removesFromList() async {
        let board1 = createTestBoard(name: "Board 1")
        let board2 = createTestBoard(name: "Board 2")
        
        mockRepository.preloadBoard(board1)
        mockRepository.preloadBoard(board2)
        
        await viewModel.load()
        XCTAssertEqual(viewModel.boards.count, 2)
        
        await viewModel.delete(id: board1.id)
        
        XCTAssertEqual(viewModel.boards.count, 1) // One board should remain
        XCTAssertEqual(viewModel.boards.first?.id, board2.id)
    }
    
    func test_delete_failure_setsError() async {
        let board = createTestBoard(name: "Test Board")
        mockRepository.preloadBoard(board)
        await viewModel.load()
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .persistenceError("Failed to delete board")
        
        await viewModel.delete(id: board.id)
        
        XCTAssertEqual(viewModel.gameError, .persistenceError("Failed to delete board"))
        XCTAssertEqual(viewModel.boards.count, 1) // Board should still be there due to failure
    }
    
    // MARK: - CreateRandomBoard Tests
    
    func test_createRandomBoard_success_addsToList() async {
        await viewModel.createRandomBoard(name: "Random Board", width: 10, height: 10, density: 0.3)
        
        XCTAssertEqual(viewModel.boards.count, 1)
        XCTAssertEqual(viewModel.boards.first?.name, "Random Board")
    }
    
    func test_createRandomBoard_withCustomName_renamesBoard() async {
        let customName = "My Custom Board"
        await viewModel.createRandomBoard(name: customName)
        
        XCTAssertEqual(viewModel.boards.count, 1)
        XCTAssertEqual(viewModel.boards.first?.name, customName)
    }
    
    func test_createRandomBoard_defaultParameters() async {
        await viewModel.createRandomBoard()
        
        XCTAssertEqual(viewModel.boards.count, 1)
        XCTAssertNotNil(viewModel.boards.first)
    }
    
    // MARK: - Recovery Action Tests
    
    func test_handleRecoveryAction_retry_reloadsBoards() async {
        viewModel.handleRecoveryAction(.retry)
        
        // Give async operation time to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertFalse(viewModel.isLoading) // Should have completed reload
    }
    
    func test_handleRecoveryAction_otherActions_doNothing() {
        // These actions should be handled by the UI layer, not the BoardListViewModel
        viewModel.handleRecoveryAction(.goBack)
        viewModel.handleRecoveryAction(.goToBoardList)
        viewModel.handleRecoveryAction(.createNew)
        viewModel.handleRecoveryAction(.continueWithoutSaving)
        viewModel.handleRecoveryAction(.cancel)
        viewModel.handleRecoveryAction(.contactSupport)
        viewModel.handleRecoveryAction(.resetBoard)
        viewModel.handleRecoveryAction(.tryAgain)
        
        // No assertions needed - just ensuring no crashes occur
        XCTAssert(true)
    }
    
    // MARK: - Performance Tests
    
    func test_performance_loadManyBoards() async {
        let boards = (0..<1000).map { i in
            createTestBoard(name: "Board \(i)")
        }
        
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        // Load first page
        await viewModel.loadFirstPage()
        
        // Load all remaining pages to get all 1000 boards
        while viewModel.hasMorePages {
            await viewModel.loadNextPage()
        }
        
        XCTAssertEqual(viewModel.boards.count, 1000)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func test_concurrentOperations_handledSafely() async {
        let boards = (0..<5).map { i in
            createTestBoard(name: "Board \(i)")
        }
        
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.load()
        
        // Run multiple operations concurrently
        await withTaskGroup(of: Void.self) { group in
            for board in boards {
                group.addTask {
                    await self.viewModel.delete(id: board.id)
                }
                group.addTask {
                    await self.viewModel.createRandomBoard(name: "New \(board.name)")
                }
            }
            group.addTask {
                await self.viewModel.load()
            }
        }
        
        // Should complete without crashing
        // Final state is unpredictable due to race conditions, but that's ok
    }
    
    // MARK: - Helper Methods
    
    private func createTestBoard(name: String, id: UUID = UUID(), createdAt: Date = Date()) -> Board {
        let cells: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        return try! Board(
            id: id,
            name: name,
            width: 3,
            height: 3,
            createdAt: createdAt,
            cells: cells
        )
    }
    
    // MARK: - Pagination Tests
    
    func test_loadFirstPage_success_loadsPaginatedResults() async {
        // Create more than one page of boards
        let boards = (0..<25).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.loadFirstPage()
        
        // Should load first 20 boards (default page size)
        XCTAssertEqual(viewModel.boards.count, 20)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(viewModel.totalCount, 25)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_loadNextPage_success_appendsResults() async {
        // Create more than one page of boards
        let boards = (0..<25).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        // Load first page
        await viewModel.loadFirstPage()
        XCTAssertEqual(viewModel.boards.count, 20)
        
        // Load next page
        await viewModel.loadNextPage()
        XCTAssertEqual(viewModel.boards.count, 25) // Should have all 25 now
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertFalse(viewModel.isLoadingMore)
    }
    
    func test_loadNextPage_whenNoMorePages_doesNotLoad() async {
        let boards = (0..<15).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.loadFirstPage()
        XCTAssertFalse(viewModel.hasMorePages) // Only 15 boards, fits in one page
        
        // Try to load next page - should not make additional call
        await viewModel.loadNextPage()
        XCTAssertEqual(viewModel.boards.count, 15) // Should remain the same
    }
    
    func test_search_success_filtersAndPaginates() async {
        // Create boards with different names
        let gameBoards = (0..<15).map { createTestBoard(name: "Game Board \($0)") }
        let testBoards = (0..<10).map { createTestBoard(name: "Test Board \($0)") }
        
        for board in gameBoards + testBoards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.search(query: "Game")
        
        XCTAssertEqual(viewModel.boards.count, 15) // All Game boards should match
        XCTAssertEqual(viewModel.searchQuery, "Game")
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_changeSortOption_success_reloadsWithNewSort() async {
        let boards = (0..<5).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.loadFirstPage()
        XCTAssertFalse(viewModel.isLoading)
        
        await viewModel.changeSortOption(.nameAscending)
        
        XCTAssertEqual(viewModel.sortOption, .nameAscending)
        XCTAssertEqual(viewModel.sortOption, .nameAscending)
    }
    
    func test_refresh_success_reloadsFirstPage() async {
        let boards = (0..<25).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        // Load multiple pages
        await viewModel.loadFirstPage()
        await viewModel.loadNextPage()
        XCTAssertEqual(viewModel.boards.count, 25)
        
        // Refresh should reset to first page
        await viewModel.refresh()
        XCTAssertEqual(viewModel.boards.count, 20) // Back to first page
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func test_shouldLoadMoreContent_returnsCorrectValue() async {
        let boards = (0..<25).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        await viewModel.loadFirstPage()
        let firstPageBoards = viewModel.boards
        
        // Should load more if we're near the end of current results and have more pages
        XCTAssertTrue(viewModel.hasMorePages)
        let nearEndBoard = firstPageBoards[firstPageBoards.count - 3] // 3 from end
        XCTAssertTrue(viewModel.shouldLoadMoreContent(for: nearEndBoard))
        
        // Should not load more if we're at the beginning
        let firstBoard = firstPageBoards[0]
        XCTAssertFalse(viewModel.shouldLoadMoreContent(for: firstBoard))
    }
    
    func test_paginationState_correctlyUpdated() async {
        let boards = (0..<25).map { createTestBoard(name: "Board \($0)") }
        for board in boards {
            mockRepository.preloadBoard(board)
        }
        
        // Initial state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertEqual(viewModel.totalCount, 0)
        
        await viewModel.loadFirstPage()
        
        // After first page load
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertEqual(viewModel.totalCount, 25)
        
        await viewModel.loadNextPage()
        
        // After loading all pages
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertFalse(viewModel.hasMorePages)
        XCTAssertEqual(viewModel.totalCount, 25)
    }
}

// MARK: - Mock GameService

final class MockGameService: GameService {
    
    var nextStateResult: Result<GameState, GameError> = .failure(.computationError("Not set"))
    var nextStateResults: [Result<GameState, GameError>] = []
    var stateAtGenerationResult: Result<GameState, GameError> = .failure(.computationError("Not set"))
    var finalStateResult: Result<GameState, GameError> = .failure(.computationError("Not set"))
    
    private var nextStateResultIndex = 0
    
    func createBoard(_ initialState: CellsGrid) async -> UUID {
        return UUID()
    }
    
    func getNextState(boardId: UUID) async -> Result<GameState, GameError> {
        
        if !nextStateResults.isEmpty {
            let result = nextStateResults[min(nextStateResultIndex, nextStateResults.count - 1)]
            nextStateResultIndex += 1
            return result
        }
        
        return nextStateResult
    }
    
    func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError> {
        return stateAtGenerationResult
    }
    
    func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError> {
        return finalStateResult
    }
    
    func reset() {
        nextStateResultIndex = 0
        nextStateResults.removeAll()
    }
}
