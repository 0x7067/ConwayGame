import XCTest
import ConwayGameEngine
@testable import ConwayGame

// MARK: - Mock Repository for Testing

final class MockBoardRepository: BoardRepository {
    private actor StorageActor {
        private var storage: [UUID: Board] = [:]
        
        func get(_ id: UUID) -> Board? {
            return storage[id]
        }
        
        func set(_ id: UUID, _ board: Board) {
            storage[id] = board
        }
        
        func remove(_ id: UUID) {
            storage.removeValue(forKey: id)
        }
        
        func getAll() -> [Board] {
            return Array(storage.values)
        }
        
        func clear() {
            storage.removeAll()
        }
        
        func count() -> Int {
            return storage.count
        }
    }
    
    private let storageActor = StorageActor()
    var shouldThrowError = false
    var errorToThrow: GameError = .computationError("Mock error")
    
    func save(_ board: Board) async throws {
        if shouldThrowError { throw errorToThrow }
        await storageActor.set(board.id, board)
    }
    
    func load(id: UUID) async throws -> Board? {
        if shouldThrowError { throw errorToThrow }
        return await storageActor.get(id)
    }
    
    func loadAll() async throws -> [Board] {
        if shouldThrowError { throw errorToThrow }
        return await storageActor.getAll()
    }
    
    func loadBoardsPaginated(offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        if shouldThrowError { throw errorToThrow }
        
        // Input validation
        guard offset >= 0, limit > 0 else {
            throw GameError.computationError("Invalid pagination parameters: offset=\(offset), limit=\(limit)")
        }
        
        let allBoards = await storageActor.getAll()
        let sortedBoards = sortBoards(allBoards, by: sortBy)
        let totalCount = sortedBoards.count
        let startIndex = min(offset, totalCount)
        let endIndex = min(offset + limit, totalCount)
        let pageBoards = startIndex < totalCount ? Array(sortedBoards[startIndex..<endIndex]) : []
        let hasMorePages = endIndex < totalCount
        let currentPage = limit > 0 ? offset / limit : 0
        
        return BoardListPage(
            boards: pageBoards,
            totalCount: totalCount,
            hasMorePages: hasMorePages,
            currentPage: currentPage,
            pageSize: limit
        )
    }
    
    func searchBoards(query: String, offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        if shouldThrowError { throw errorToThrow }
        
        // Input validation
        guard offset >= 0, limit > 0 else {
            throw GameError.computationError("Invalid pagination parameters: offset=\(offset), limit=\(limit)")
        }
        
        let allBoards = await storageActor.getAll()
        let filteredBoards = query.isEmpty ? allBoards : allBoards.filter { board in
            board.name.localizedCaseInsensitiveContains(query)
        }
        let sortedBoards = sortBoards(filteredBoards, by: sortBy)
        let totalCount = sortedBoards.count
        let startIndex = min(offset, totalCount)
        let endIndex = min(offset + limit, totalCount)
        let pageBoards = startIndex < totalCount ? Array(sortedBoards[startIndex..<endIndex]) : []
        let hasMorePages = endIndex < totalCount
        let currentPage = limit > 0 ? offset / limit : 0
        
        return BoardListPage(
            boards: pageBoards,
            totalCount: totalCount,
            hasMorePages: hasMorePages,
            currentPage: currentPage,
            pageSize: limit
        )
    }
    
    func getTotalBoardCount() async throws -> Int {
        if shouldThrowError { throw errorToThrow }
        return await storageActor.count()
    }
    
    private func sortBoards(_ boards: [Board], by sortOption: BoardSortOption) -> [Board] {
        switch sortOption {
        case .createdAtDescending:
            return boards.sorted { $0.createdAt > $1.createdAt }
        case .createdAtAscending:
            return boards.sorted { $0.createdAt < $1.createdAt }
        case .nameAscending:
            return boards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return boards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .generationDescending:
            return boards.sorted { $0.currentGeneration > $1.currentGeneration }
        case .generationAscending:
            return boards.sorted { $0.currentGeneration < $1.currentGeneration }
        }
    }
    
    func delete(id: UUID) async throws {
        if shouldThrowError { throw errorToThrow }
        await storageActor.remove(id)
    }
    
    func rename(id: UUID, newName: String) async throws {
        if shouldThrowError { throw errorToThrow }
        guard var board = await storageActor.get(id) else {
            throw GameError.boardNotFound(id)
        }
        board.name = newName
        await storageActor.set(id, board)
    }
    
    func reset(id: UUID) async throws -> Board {
        if shouldThrowError {
            throw errorToThrow
        }
        guard var board = await storageActor.get(id) else {
            throw GameError.boardNotFound(id)
        }
        board.cells = board.initialCells
        board.currentGeneration = 0
        board.stateHistory = [BoardHashing.hash(for: board.initialCells)]
        await storageActor.set(id, board)
        return board
    }
    
    // Test helpers
    func clear() async {
        await storageActor.clear()
        shouldThrowError = false
    }
    
    func preloadBoard(_ board: Board) async {
        await storageActor.set(board.id, board)
    }
    
    var storedBoardCount: Int {
        get async {
            return await storageActor.count()
        }
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
    
    // MARK: - Pagination Tests
    
    func testLoadBoardsPaginatedEmptyRepositoryReturnsEmptyPage() async throws {
        let page = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .createdAtDescending)
        
        XCTAssertEqual(page.boards.count, 0)
        XCTAssertEqual(page.totalCount, 0)
        XCTAssertFalse(page.hasMorePages)
        XCTAssertEqual(page.currentPage, 0)
        XCTAssertEqual(page.pageSize, 10)
    }
    
    func testLoadBoardsPaginatedFirstPageReturnsCorrectResults() async throws {
        // Create 15 boards with different creation dates
        _ = try await createTestBoards(count: 15)
        
        let page = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .createdAtDescending)
        
        XCTAssertEqual(page.boards.count, 10)
        XCTAssertEqual(page.totalCount, 15)
        XCTAssertTrue(page.hasMorePages)
        XCTAssertEqual(page.currentPage, 0)
        XCTAssertEqual(page.pageSize, 10)
        
        // Verify boards are sorted by creation date descending
        for i in 1..<page.boards.count {
            XCTAssertGreaterThanOrEqual(page.boards[i-1].createdAt, page.boards[i].createdAt)
        }
    }
    
    func testLoadBoardsPaginatedSecondPageReturnsRemainingResults() async throws {
        _ = try await createTestBoards(count: 15)
        
        let page = try await repository.loadBoardsPaginated(offset: 10, limit: 10, sortBy: .createdAtDescending)
        
        XCTAssertEqual(page.boards.count, 5)
        XCTAssertEqual(page.totalCount, 15)
        XCTAssertFalse(page.hasMorePages)
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.pageSize, 10)
    }
    
    func testLoadBoardsPaginatedOffsetBeyondTotalReturnsEmptyPage() async throws {
        _ = try await createTestBoards(count: 5)
        
        let page = try await repository.loadBoardsPaginated(offset: 10, limit: 10, sortBy: .createdAtDescending)
        
        XCTAssertEqual(page.boards.count, 0)
        XCTAssertEqual(page.totalCount, 5)
        XCTAssertFalse(page.hasMorePages)
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.pageSize, 10)
    }
    
    func test_loadBoardsPaginated_sortByName_sortsCorrectly() async throws {
        let board1 = try createTestBoard(name: "Alpha Board")
        let board2 = try createTestBoard(name: "Charlie Board")
        let board3 = try createTestBoard(name: "Beta Board")
        
        try await repository.save(board1)
        try await repository.save(board2)
        try await repository.save(board3)
        
        let pageAsc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .nameAscending)
        XCTAssertEqual(pageAsc.boards[0].name, "Alpha Board")
        XCTAssertEqual(pageAsc.boards[1].name, "Beta Board")
        XCTAssertEqual(pageAsc.boards[2].name, "Charlie Board")
        
        let pageDesc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .nameDescending)
        XCTAssertEqual(pageDesc.boards[0].name, "Charlie Board")
        XCTAssertEqual(pageDesc.boards[1].name, "Beta Board")
        XCTAssertEqual(pageDesc.boards[2].name, "Alpha Board")
    }
    
    func test_searchBoards_emptyQuery_returnsAllBoards() async throws {
        _ = try await createTestBoards(count: 5)
        
        let page = try await repository.searchBoards(query: "", offset: 0, limit: 10, sortBy: .createdAtDescending)
        
        XCTAssertEqual(page.boards.count, 5)
        XCTAssertEqual(page.totalCount, 5)
        XCTAssertFalse(page.hasMorePages)
    }
    
    func test_searchBoards_withQuery_filtersCorrectly() async throws {
        let board1 = try createTestBoard(name: "Game Board")
        let board2 = try createTestBoard(name: "Test Board")
        let board3 = try createTestBoard(name: "Another Game")
        
        try await repository.save(board1)
        try await repository.save(board2)
        try await repository.save(board3)
        
        let page = try await repository.searchBoards(query: "Game", offset: 0, limit: 10, sortBy: .nameAscending)
        
        XCTAssertEqual(page.boards.count, 2)
        XCTAssertEqual(page.totalCount, 2)
        XCTAssertFalse(page.hasMorePages)
        
        let boardNames = page.boards.map(\.name).sorted()
        XCTAssertEqual(boardNames, ["Another Game", "Game Board"])
    }
    
    func test_searchBoards_caseInsensitive_filtersCorrectly() async throws {
        let board1 = try createTestBoard(name: "UPPER CASE")
        let board2 = try createTestBoard(name: "lower case")
        let board3 = try createTestBoard(name: "Mixed Case")
        
        try await repository.save(board1)
        try await repository.save(board2)
        try await repository.save(board3)
        
        let page = try await repository.searchBoards(query: "case", offset: 0, limit: 10, sortBy: .nameAscending)
        
        XCTAssertEqual(page.boards.count, 3)
        XCTAssertEqual(page.totalCount, 3)
    }
    
    func testSearchBoardsWithPaginationWorksCorrectly() async throws {
        // Create boards with names that will match search
        for i in 0..<15 {
            let board = try createTestBoard(name: "Test Board \(i)")
            try await repository.save(board)
        }
        
        let firstPage = try await repository.searchBoards(query: "Test", offset: 0, limit: 10, sortBy: .nameAscending)
        XCTAssertEqual(firstPage.boards.count, 10)
        XCTAssertEqual(firstPage.totalCount, 15)
        XCTAssertTrue(firstPage.hasMorePages)
        
        let secondPage = try await repository.searchBoards(query: "Test", offset: 10, limit: 10, sortBy: .nameAscending)
        XCTAssertEqual(secondPage.boards.count, 5)
        XCTAssertEqual(secondPage.totalCount, 15)
        XCTAssertFalse(secondPage.hasMorePages)
    }
    
    func test_getTotalBoardCount_emptyRepository_returnsZero() async throws {
        let count = try await repository.getTotalBoardCount()
        XCTAssertEqual(count, 0)
    }
    
    func test_getTotalBoardCount_withBoards_returnsCorrectCount() async throws {
        _ = try await createTestBoards(count: 7)
        
        let count = try await repository.getTotalBoardCount()
        XCTAssertEqual(count, 7)
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
    
    private func createTestBoards(count: Int) async throws -> [Board] {
        var boards: [Board] = []
        for i in 0..<count {
            // Create boards with different creation dates by adding milliseconds
            let createdAt = Date().addingTimeInterval(TimeInterval(i) * 0.001)
            let board = try Board(
                name: "Test Board \(i)",
                width: 3,
                height: 3,
                createdAt: createdAt,
                cells: [
                    [true,  false, true],
                    [false, true,  false],
                    [true,  false, true]
                ]
            )
            try await repository.save(board)
            boards.append(board)
        }
        return boards
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
    
    func test_mock_behaviorVerification() async throws {
        let board = try createTestBoard()
        
        // Test save - verify board is stored
        try await mockRepository.save(board)
        let countAfterSave = await mockRepository.storedBoardCount
        XCTAssertEqual(countAfterSave, 1)
        
        // Test load - verify board can be retrieved
        let loadedBoard = try await mockRepository.load(id: board.id)
        XCTAssertEqual(loadedBoard, board)
        
        // Test loadAll - verify all boards are returned
        let allBoards = try await mockRepository.loadAll()
        XCTAssertEqual(allBoards.count, 1)
        XCTAssertEqual(allBoards.first, board)
        
        // Test rename - verify name is updated
        try await mockRepository.rename(id: board.id, newName: "New Name")
        let renamedBoard = try await mockRepository.load(id: board.id)
        XCTAssertEqual(renamedBoard?.name, "New Name")
        
        // Test reset - verify board is reset to initial state
        let resetBoard = try await mockRepository.reset(id: board.id)
        XCTAssertEqual(resetBoard.cells, board.initialCells)
        XCTAssertEqual(resetBoard.currentGeneration, 0)
        
        // Test delete - verify board is removed
        try await mockRepository.delete(id: board.id)
        let countAfterDelete = await mockRepository.storedBoardCount
        XCTAssertEqual(countAfterDelete, 0)
        let deletedBoard = try await mockRepository.load(id: board.id)
        XCTAssertNil(deletedBoard)
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
        await mockRepository.preloadBoard(board)
        
        let countAfterPreload = await mockRepository.storedBoardCount
        XCTAssertEqual(countAfterPreload, 1)
        
        let loaded = try await mockRepository.load(id: board.id)
        XCTAssertEqual(loaded, board)
    }
    
    func test_mock_clear() async throws {
        let board = try createTestBoard()
        try await mockRepository.save(board)
        let countAfterSave = await mockRepository.storedBoardCount
        XCTAssertEqual(countAfterSave, 1)
        
        await mockRepository.clear()
        
        let countAfterClear = await mockRepository.storedBoardCount
        XCTAssertEqual(countAfterClear, 0)
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