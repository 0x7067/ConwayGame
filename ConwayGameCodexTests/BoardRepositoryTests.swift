import XCTest
@testable import ConwayGameCodex

// MARK: - Mock Repository for Testing

final class MockBoardRepository: BoardRepository {
    private var storage: [UUID: Board] = [:]
    var saveCallCount = 0
    var loadCallCount = 0
    var loadAllCallCount = 0
    var deleteCallCount = 0
    var renameCallCount = 0
    var resetCallCount = 0
    var shouldThrowError = false
    var errorToThrow: GameError = .computationError("Mock error")
    
    func save(_ board: Board) async throws {
        saveCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        storage[board.id] = board
    }
    
    func load(id: UUID) async throws -> Board? {
        loadCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return storage[id]
    }
    
    func loadAll() async throws -> [Board] {
        loadAllCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return Array(storage.values)
    }
    
    func delete(id: UUID) async throws {
        deleteCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        storage.removeValue(forKey: id)
    }
    
    func rename(id: UUID, newName: String) async throws {
        renameCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        guard var board = storage[id] else {
            throw GameError.boardNotFound(id)
        }
        board.name = newName
        storage[id] = board
    }
    
    func reset(id: UUID) async throws -> Board {
        resetCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        guard var board = storage[id] else {
            throw GameError.boardNotFound(id)
        }
        board.cells = board.initialCells
        board.currentGeneration = 0
        board.stateHistory = [BoardHashing.hash(for: board.initialCells)]
        storage[id] = board
        return board
    }
    
    // Test helpers
    func clear() {
        storage.removeAll()
        saveCallCount = 0
        loadCallCount = 0
        loadAllCallCount = 0
        deleteCallCount = 0
        renameCallCount = 0
        resetCallCount = 0
        shouldThrowError = false
    }
    
    func preloadBoard(_ board: Board) {
        storage[board.id] = board
    }
    
    var storedBoardCount: Int {
        storage.count
    }
}

// MARK: - InMemoryBoardRepository Tests

final class InMemoryBoardRepositoryTests: XCTestCase {
    private var repository: InMemoryBoardRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repository = InMemoryBoardRepository()
    }
    
    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func test_save_newBoard_storesSuccessfully() async throws {
        let board = try createTestBoard()
        
        try await repository.save(board)
        let loaded = try await repository.load(id: board.id)
        
        XCTAssertEqual(loaded, board)
    }
    
    func test_save_updateExistingBoard_overwritesSuccessfully() async throws {
        var board = try createTestBoard()
        try await repository.save(board)
        
        // Modify board
        board.name = "Updated Name"
        board.currentGeneration = 5
        try await repository.save(board)
        
        let loaded = try await repository.load(id: board.id)
        XCTAssertEqual(loaded?.name, "Updated Name")
        XCTAssertEqual(loaded?.currentGeneration, 5)
    }
    
    // MARK: - Load Tests
    
    func test_load_existingBoard_returnsBoard() async throws {
        let board = try createTestBoard()
        try await repository.save(board)
        
        let loaded = try await repository.load(id: board.id)
        XCTAssertEqual(loaded, board)
    }
    
    func test_load_nonexistentBoard_returnsNil() async throws {
        let nonexistentId = UUID()
        let loaded = try await repository.load(id: nonexistentId)
        XCTAssertNil(loaded)
    }
    
    // MARK: - LoadAll Tests
    
    func test_loadAll_emptyRepository_returnsEmptyArray() async throws {
        let boards = try await repository.loadAll()
        XCTAssertTrue(boards.isEmpty)
    }
    
    func test_loadAll_multipleBoards_returnsAllBoards() async throws {
        let board1 = try createTestBoard(name: "Board 1")
        let board2 = try createTestBoard(name: "Board 2")
        let board3 = try createTestBoard(name: "Board 3")
        
        try await repository.save(board1)
        try await repository.save(board2)
        try await repository.save(board3)
        
        let boards = try await repository.loadAll()
        XCTAssertEqual(boards.count, 3)
        
        let ids = Set(boards.map(\.id))
        XCTAssertTrue(ids.contains(board1.id))
        XCTAssertTrue(ids.contains(board2.id))
        XCTAssertTrue(ids.contains(board3.id))
    }
    
    // MARK: - Delete Tests
    
    func test_delete_existingBoard_removesBoard() async throws {
        let board = try createTestBoard()
        try await repository.save(board)
        
        try await repository.delete(id: board.id)
        let loaded = try await repository.load(id: board.id)
        XCTAssertNil(loaded)
    }
    
    func test_delete_nonexistentBoard_doesNotThrow() async throws {
        let nonexistentId = UUID()
        // Should not throw
        try await repository.delete(id: nonexistentId)
    }
    
    func test_delete_multipleBoards_deletesCorrectBoard() async throws {
        let board1 = try createTestBoard(name: "Board 1")
        let board2 = try createTestBoard(name: "Board 2")
        
        try await repository.save(board1)
        try await repository.save(board2)
        
        try await repository.delete(id: board1.id)
        
        let loaded1 = try await repository.load(id: board1.id)
        let loaded2 = try await repository.load(id: board2.id)
        
        XCTAssertNil(loaded1)
        XCTAssertNotNil(loaded2)
        XCTAssertEqual(loaded2, board2)
    }
    
    // MARK: - Rename Tests
    
    func test_rename_existingBoard_updatesName() async throws {
        let board = try createTestBoard(name: "Original Name")
        try await repository.save(board)
        
        try await repository.rename(id: board.id, newName: "New Name")
        let loaded = try await repository.load(id: board.id)
        
        XCTAssertEqual(loaded?.name, "New Name")
    }
    
    func test_rename_nonexistentBoard_throwsBoardNotFound() async throws {
        let nonexistentId = UUID()
        
        do {
            try await repository.rename(id: nonexistentId, newName: "New Name")
            XCTFail("Expected boardNotFound error")
        } catch GameError.boardNotFound(let id) {
            XCTAssertEqual(id, nonexistentId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Reset Tests
    
    func test_reset_existingBoard_resetsToInitialState() async throws {
        var board = try createTestBoard()
        
        // Modify the board state
        board.cells = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ]
        board.currentGeneration = 10
        board.stateHistory = ["hash1", "hash2", "hash3"]
        
        try await repository.save(board)
        
        let resetBoard = try await repository.reset(id: board.id)
        
        XCTAssertEqual(resetBoard.cells, board.initialCells)
        XCTAssertEqual(resetBoard.currentGeneration, 0)
        XCTAssertEqual(resetBoard.stateHistory.count, 1)
        XCTAssertEqual(resetBoard.stateHistory.first, BoardHashing.hash(for: board.initialCells))
    }
    
    func test_reset_nonexistentBoard_throwsBoardNotFound() async throws {
        let nonexistentId = UUID()
        
        do {
            _ = try await repository.reset(id: nonexistentId)
            XCTFail("Expected boardNotFound error")
        } catch GameError.boardNotFound(let id) {
            XCTAssertEqual(id, nonexistentId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Concurrency Tests
    
    func test_concurrentAccess_multipleSaves() async throws {
        let boardCount = 100
        let boards = try (0..<boardCount).map { i in
            try createTestBoard(name: "Board \(i)")
        }
        
        // Concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for board in boards {
                group.addTask {
                    try? await self.repository.save(board)
                }
            }
        }
        
        let loadedBoards = try await repository.loadAll()
        XCTAssertEqual(loadedBoards.count, boardCount)
    }
    
    func test_concurrentAccess_mixedOperations() async throws {
        let board = try createTestBoard()
        try await repository.save(board)
        
        // Concurrent operations on the same board
        await withTaskGroup(of: Void.self) { group in
            // Multiple renames
            for i in 0..<10 {
                group.addTask {
                    try? await self.repository.rename(id: board.id, newName: "Name \(i)")
                }
            }
            
            // Multiple loads
            for _ in 0..<20 {
                group.addTask {
                    _ = try? await self.repository.load(id: board.id)
                }
            }
            
            // One reset
            group.addTask {
                _ = try? await self.repository.reset(id: board.id)
            }
        }
        
        // Should still have the board
        let loaded = try await repository.load(id: board.id)
        XCTAssertNotNil(loaded)
    }
    
    // MARK: - Helper Methods
    
    private func createTestBoard(
        name: String = "Test Board",
        width: Int = 3,
        height: Int = 3
    ) throws -> Board {
        let cells: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        return try Board(
            name: name,
            width: width,
            height: height,
            cells: cells
        )
    }
}

// MARK: - MockBoardRepository Tests

final class MockBoardRepositoryTests: XCTestCase {
    private var mockRepository: MockBoardRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockBoardRepository()
    }
    
    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }
    
    func test_mock_callCounters() async throws {
        let board = try createTestBoard()
        
        // Test save
        try await mockRepository.save(board)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
        
        // Test load
        _ = try await mockRepository.load(id: board.id)
        XCTAssertEqual(mockRepository.loadCallCount, 1)
        
        // Test loadAll
        _ = try await mockRepository.loadAll()
        XCTAssertEqual(mockRepository.loadAllCallCount, 1)
        
        // Test rename
        try await mockRepository.rename(id: board.id, newName: "New Name")
        XCTAssertEqual(mockRepository.renameCallCount, 1)
        
        // Test reset
        _ = try await mockRepository.reset(id: board.id)
        XCTAssertEqual(mockRepository.resetCallCount, 1)
        
        // Test delete
        try await mockRepository.delete(id: board.id)
        XCTAssertEqual(mockRepository.deleteCallCount, 1)
    }
    
    func test_mock_errorThrowing() async throws {
        let board = try createTestBoard()
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = .computationError("Test error")
        
        do {
            try await mockRepository.save(board)
            XCTFail("Expected error to be thrown")
        } catch GameError.computationError(let message) {
            XCTAssertEqual(message, "Test error")
        }
    }
    
    func test_mock_preloadBoard() async throws {
        let board = try createTestBoard()
        mockRepository.preloadBoard(board)
        
        XCTAssertEqual(mockRepository.storedBoardCount, 1)
        
        let loaded = try await mockRepository.load(id: board.id)
        XCTAssertEqual(loaded, board)
        XCTAssertEqual(mockRepository.loadCallCount, 1)
    }
    
    func test_mock_clear() async throws {
        let board = try createTestBoard()
        try await mockRepository.save(board)
        XCTAssertEqual(mockRepository.saveCallCount, 1)
        XCTAssertEqual(mockRepository.storedBoardCount, 1)
        
        mockRepository.clear()
        
        XCTAssertEqual(mockRepository.saveCallCount, 0)
        XCTAssertEqual(mockRepository.storedBoardCount, 0)
    }
    
    private func createTestBoard() throws -> Board {
        try Board(
            name: "Test Board",
            width: 3,
            height: 3,
            cells: [
                [true,  false, true],
                [false, true,  false],
                [true,  false, true]
            ]
        )
    }
}

// MARK: - Board Model Tests

final class BoardTests: XCTestCase {
    
    func test_init_validBoard_createsSuccessfully() throws {
        let cells: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        let board = try Board(
            name: "Test Board",
            width: 3,
            height: 3,
            cells: cells
        )
        
        XCTAssertEqual(board.name, "Test Board")
        XCTAssertEqual(board.width, 3)
        XCTAssertEqual(board.height, 3)
        XCTAssertEqual(board.cells, cells)
        XCTAssertEqual(board.initialCells, cells)
        XCTAssertEqual(board.currentGeneration, 0)
        XCTAssertTrue(board.isActive)
        XCTAssertNotNil(board.id)
    }
    
    func test_init_withInitialCells_setsCorrectly() throws {
        let currentCells: CellsGrid = [
            [false, false, false],
            [false, false, false],
            [false, false, false]
        ]
        let initialCells: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        
        let board = try Board(
            name: "Test Board",
            width: 3,
            height: 3,
            cells: currentCells,
            initialCells: initialCells
        )
        
        XCTAssertEqual(board.cells, currentCells)
        XCTAssertEqual(board.initialCells, initialCells)
    }
    
    func test_init_invalidDimensions_throwsError() {
        XCTAssertThrowsError(try Board(
            name: "Invalid Board",
            width: 0,
            height: 5,
            cells: []
        )) { error in
            XCTAssertEqual(error as? GameError, GameError.invalidBoardDimensions)
        }
        
        XCTAssertThrowsError(try Board(
            name: "Invalid Board",
            width: 5,
            height: 0,
            cells: []
        )) { error in
            XCTAssertEqual(error as? GameError, GameError.invalidBoardDimensions)
        }
        
        XCTAssertThrowsError(try Board(
            name: "Invalid Board",
            width: 1001,
            height: 5,
            cells: []
        )) { error in
            XCTAssertEqual(error as? GameError, GameError.invalidBoardDimensions)
        }
    }
    
    func test_init_invalidCellsDimensions_throwsError() {
        let cells: CellsGrid = [
            [true,  false],
            [false, true,  false] // Wrong width
        ]
        
        XCTAssertThrowsError(try Board(
            name: "Invalid Board",
            width: 3,
            height: 2,
            cells: cells
        )) { error in
            XCTAssertEqual(error as? GameError, GameError.invalidBoardDimensions)
        }
    }
    
    func test_validate_validBoard_doesNotThrow() throws {
        let board = try Board(
            name: "Valid Board",
            width: 3,
            height: 3,
            cells: [
                [true,  false, true],
                [false, true,  false],
                [true,  false, true]
            ]
        )
        
        // Should not throw
        try board.validate()
    }
    
    func test_codable_encodeDecode() throws {
        let originalBoard = try Board(
            name: "Codable Test",
            width: 2,
            height: 2,
            cells: [
                [true,  false],
                [false, true]
            ]
        )
        
        let encoded = try JSONEncoder().encode(originalBoard)
        let decoded = try JSONDecoder().decode(Board.self, from: encoded)
        
        XCTAssertEqual(decoded.id, originalBoard.id)
        XCTAssertEqual(decoded.name, originalBoard.name)
        XCTAssertEqual(decoded.width, originalBoard.width)
        XCTAssertEqual(decoded.height, originalBoard.height)
        XCTAssertEqual(decoded.cells, originalBoard.cells)
        XCTAssertEqual(decoded.initialCells, originalBoard.initialCells)
        XCTAssertEqual(decoded.currentGeneration, originalBoard.currentGeneration)
        XCTAssertEqual(decoded.isActive, originalBoard.isActive)
    }
    
    func test_hashable_equalBoards() throws {
        let cells: CellsGrid = [
            [true,  false],
            [false, true]
        ]
        
        let id = UUID()
        let createdAt = Date()
        let board1 = try Board(id: id, name: "Board", width: 2, height: 2, createdAt: createdAt, cells: cells)
        let board2 = try Board(id: id, name: "Board", width: 2, height: 2, createdAt: createdAt, cells: cells)
        
        XCTAssertEqual(board1, board2)
        XCTAssertEqual(board1.hashValue, board2.hashValue)
    }
    
    func test_hashable_differentBoards() throws {
        let board1 = try Board(name: "Board 1", width: 2, height: 2, cells: [[true, false], [false, true]])
        let board2 = try Board(name: "Board 2", width: 2, height: 2, cells: [[false, true], [true, false]])
        
        XCTAssertNotEqual(board1, board2)
        XCTAssertNotEqual(board1.hashValue, board2.hashValue)
    }
}