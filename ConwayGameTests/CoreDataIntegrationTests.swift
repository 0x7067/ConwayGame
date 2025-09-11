import XCTest
import ConwayGameEngine
import CoreData
import FactoryKit
@testable import ConwayGame

final class CoreDataIntegrationTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var repository: CoreDataBoardRepository!
    private var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for isolated testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        repository = CoreDataBoardRepository(container: persistenceController.container)
    }
    
    override func tearDown() {
        persistenceController = nil
        repository = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Core Data Stack Integration Tests
    
    func testCoreDataStackInitialization() throws {
        XCTAssertNotNil(persistenceController.container)
        XCTAssertNotNil(context)
        XCTAssertEqual(context.persistentStoreCoordinator?.persistentStores.count, 1)
        
        // Verify the store is in-memory for testing
        let store = context.persistentStoreCoordinator?.persistentStores.first
        XCTAssertEqual(store?.type, NSInMemoryStoreType)
    }
    
    func testCoreDataModelValidation() throws {
        let model = context.persistentStoreCoordinator?.managedObjectModel
        XCTAssertNotNil(model)
        
        // Verify BoardEntity exists with expected attributes
        let boardEntity = model?.entitiesByName["BoardEntity"]
        XCTAssertNotNil(boardEntity)
        
        let expectedAttributes = [
            "id", "name", "width", "height", "createdAt",
            "cellsData", "currentGeneration", "isActive", "stateHistoryData"
        ]
        for attribute in expectedAttributes {
            XCTAssertNotNil(boardEntity?.attributesByName[attribute], "Missing attribute: \(attribute)")
        }
    }
    
    // MARK: - CRUD Operations Integration Tests
    
    func testCreateBoardIntegration() async throws {
        let board = try Board(
            id: UUID(),
            name: "Test Board",
            width: 5,
            height: 5,
            cells: [
                [true,  false, true,  false, true],
                [false, true,  false, true,  false],
                [true,  false, true,  false, true],
                [false, true,  false, true,  false],
                [true,  false, true,  false, true]
            ]
        )
        
        // Test save operation
        try await repository.save(board)
        
        // Verify save to Core Data
        let request: NSFetchRequest<BoardEntity> = BoardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", board.id as CVarArg)
        
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 1)
        
        let savedEntity = entities.first!
        XCTAssertEqual(savedEntity.id, board.id)
        XCTAssertEqual(savedEntity.name, board.name)
        XCTAssertEqual(savedEntity.width, Int16(board.width))
        XCTAssertEqual(savedEntity.height, Int16(board.height))
        XCTAssertNotNil(savedEntity.cellsData)
    }
    
    func testReadBoardIntegration() async throws {
        func encodeCells(_ cells: CellsGrid) -> Data {
            let h = cells.count
            let w = h > 0 ? cells[0].count : 0
            if h == 0 || w == 0 { return Data() }
            let bitCount = w * h
            var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
            var bitIndex = 0
            for y in 0..<h {
                for x in 0..<w {
                    if cells[y][x] {
                        let byteIndex = bitIndex / 8
                        let bitInByte = UInt8(7 - (bitIndex % 8))
                        bytes[byteIndex] |= (1 << bitInByte)
                    }
                    bitIndex += 1
                }
            }
            return Data(bytes)
        }
        // Create board directly in Core Data
        let boardId = UUID()
        let boardEntity = BoardEntity(context: context)
        boardEntity.id = boardId
        boardEntity.name = "Direct Core Data Board"
        boardEntity.width = 3
        boardEntity.height = 3
        boardEntity.createdAt = Date()
        boardEntity.currentGeneration = 0
        boardEntity.isActive = true
        // Note: BoardEntity doesn't have updatedAt field
        
        let cells: CellsGrid = [
            [true,  false, true],
            [false, true,  false],
            [true,  false, true]
        ]
        boardEntity.cellsData = encodeCells(cells)
        // Provide minimal state history per model requirement
        let initialHash = BoardHashing.hash(for: cells)
        boardEntity.stateHistoryData = try JSONEncoder().encode([initialHash])
        
        try context.save()
        
        // Test repository read operation
        let retrievedBoard = try await repository.load(id: boardId)
        XCTAssertNotNil(retrievedBoard)
        XCTAssertEqual(retrievedBoard?.id, boardId)
        XCTAssertEqual(retrievedBoard?.name, "Direct Core Data Board")
        XCTAssertEqual(retrievedBoard?.cells, cells)
    }
    
    func testUpdateBoardIntegration() async throws {
        // Create initial board
        let originalBoard = try Board(
            id: UUID(),
            name: "Original Board",
            width: 3,
            height: 3,
            cells: [
                [true,  false, true],
                [false, false, false],
                [true,  false, true]
            ]
        )
        
        try await repository.save(originalBoard)
        
        // Update board
        let updatedCells: CellsGrid = [
            [false, true,  false],
            [true,  true,  true],
            [false, true,  false]
        ]
        
        let updatedBoard = try Board(
            id: originalBoard.id,
            name: "Updated Board",
            width: 3,
            height: 3,
            createdAt: originalBoard.createdAt,
            cells: updatedCells
        )
        
        try await repository.save(updatedBoard)
        
        // Verify update in Core Data
        let retrievedBoard = try await repository.load(id: originalBoard.id)
        XCTAssertNotNil(retrievedBoard)
        XCTAssertEqual(retrievedBoard?.name, "Updated Board")
        XCTAssertEqual(retrievedBoard?.cells, updatedCells)
        XCTAssertEqual(retrievedBoard?.createdAt, originalBoard.createdAt) // Should preserve creation date
    }
    
    func testDeleteBoardIntegration() async throws {
        let board = try Board(
            id: UUID(),
            name: "Board to Delete",
            width: 2,
            height: 2,
            cells: [[true, false], [false, true]]
        )
        
        try await repository.save(board)
        
        // Verify board exists
        let existingBoard = try await repository.load(id: board.id)
        XCTAssertNotNil(existingBoard)
        
        // Delete board
        try await repository.delete(id: board.id)
        
        // Verify board is deleted
        let deletedBoard = try await repository.load(id: board.id)
        XCTAssertNil(deletedBoard)
        
        // Verify Core Data deletion
        let request: NSFetchRequest<BoardEntity> = BoardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", board.id as CVarArg)
        
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 0)
    }
    
    // MARK: - Pagination Integration Tests
    
    func testPaginationIntegration() async throws {
        // Create multiple boards for pagination testing
        let boardCount = 25
        for i in 0..<boardCount {
            let board = try Board(
                id: UUID(),
                name: "Board \(String(format: "%02d", i))",
                width: 3,
                height: 3,
                cells: [
                    [i % 2 == 0, false, i % 3 == 0],
                    [false, true, false],
                    [i % 5 == 0, false, i % 7 == 0]
                ]
            )
            try await repository.save(board)
            
            // Add small delay to ensure different timestamps
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        // Test first page
        let firstPageResult = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 10,
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(firstPageResult.boards.count, 10)
        XCTAssertEqual(firstPageResult.totalCount, boardCount)
        XCTAssertTrue(firstPageResult.hasMorePages)
        XCTAssertEqual(firstPageResult.currentPage, 0)
        
        // Verify sorting (newest first)
        let firstBoard = firstPageResult.boards.first!
        let secondBoard = firstPageResult.boards[1]
        XCTAssertGreaterThanOrEqual(firstBoard.createdAt, secondBoard.createdAt)
        
        // Test second page
        let secondPageResult = try await repository.loadBoardsPaginated(
            offset: 10,
            limit: 10,
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(secondPageResult.boards.count, 10)
        XCTAssertEqual(secondPageResult.totalCount, boardCount)
        XCTAssertTrue(secondPageResult.hasMorePages)
        XCTAssertEqual(secondPageResult.currentPage, 1)
        
        // Test last page
        let lastPageResult = try await repository.loadBoardsPaginated(
            offset: 20,
            limit: 10,
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(lastPageResult.boards.count, 5) // Remaining 5 boards
        XCTAssertEqual(lastPageResult.totalCount, boardCount)
        XCTAssertFalse(lastPageResult.hasMorePages)
        XCTAssertEqual(lastPageResult.currentPage, 2)
    }
    
    func testSearchIntegration() async throws {
        // Create boards with different names for search testing
        let gameBoards = ["Game Board Alpha", "Game Board Beta", "Game Board Gamma"]
        let testBoards = ["Test Board 1", "Test Board 2", "Unit Test Board"]
        let otherBoards = ["Random Board", "Conway's Pattern", "Life Simulation"]
        
        for name in gameBoards + testBoards + otherBoards {
            let board = try Board(
                id: UUID(),
                name: name,
                width: 3,
                height: 3,
                cells: [[true, false, true], [false, true, false], [true, false, true]]
            )
            try await repository.save(board)
        }
        
        // Test search for "Game"
        let gameSearchResult = try await repository.searchBoards(
            query: "Game",
            offset: 0,
            limit: 20,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(gameSearchResult.boards.count, 3)
        for board in gameSearchResult.boards {
            XCTAssertTrue(board.name.localizedCaseInsensitiveContains("Game"))
        }
        
        // Test search for "Test"
        let testSearchResult = try await repository.searchBoards(
            query: "Test",
            offset: 0,
            limit: 20,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(testSearchResult.boards.count, 3)
        for board in testSearchResult.boards {
            XCTAssertTrue(board.name.localizedCaseInsensitiveContains("Test"))
        }
        
        // Test search with no results
        let noResultsSearch = try await repository.searchBoards(
            query: "NonExistent",
            offset: 0,
            limit: 20,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(noResultsSearch.boards.count, 0)
        XCTAssertEqual(noResultsSearch.totalCount, 0)
    }
    
    func testSortingIntegration() async throws {
        // Create boards with known creation order and names
        let boardData = [
            ("Zebra Board", 1),
            ("Alpha Board", 2),
            ("Beta Board", 3),
            ("Gamma Board", 4)
        ]
        
        var createdBoards: [(Board, Date)] = []
        
        for (name, _) in boardData {
            let board = try Board(
                id: UUID(),
                name: name,
                width: 3,
                height: 3,
                cells: [[true, false, true], [false, true, false], [true, false, true]]
            )
            try await repository.save(board)
            createdBoards.append((board, Date()))
            
            // Ensure different timestamps
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Test name ascending sort
        let nameAscResult = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 10,
            sortBy: .nameAscending
        )
        
        let nameAscNames = nameAscResult.boards.map { $0.name }
        XCTAssertEqual(nameAscNames, ["Alpha Board", "Beta Board", "Gamma Board", "Zebra Board"])
        
        // Test name descending sort
        let nameDescResult = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 10,
            sortBy: .nameDescending
        )
        
        let nameDescNames = nameDescResult.boards.map { $0.name }
        XCTAssertEqual(nameDescNames, ["Zebra Board", "Gamma Board", "Beta Board", "Alpha Board"])
        
        // Test created date descending (newest first)
        let dateDescResult = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 10,
            sortBy: .createdAtDescending
        )
        
        let dateDescNames = dateDescResult.boards.map { $0.name }
        XCTAssertEqual(dateDescNames, ["Gamma Board", "Beta Board", "Alpha Board", "Zebra Board"])
        
        // Test created date ascending (oldest first)
        let dateAscResult = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 10,
            sortBy: .createdAtAscending
        )
        
        let dateAscNames = dateAscResult.boards.map { $0.name }
        XCTAssertEqual(dateAscNames, ["Zebra Board", "Alpha Board", "Beta Board", "Gamma Board"])
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentReadWriteOperations() async throws {
        let boardIds = (0..<10).map { _ in UUID() }
        
        // Test concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for (index, boardId) in boardIds.enumerated() {
                group.addTask {
                    let board = try! Board(
                        id: boardId,
                        name: "Concurrent Board \(index)",
                        width: 3,
                        height: 3,
                        cells: [[true, false, true], [false, true, false], [true, false, true]]
                    )
                    try! await self.repository.save(board)
                }
            }
        }
        
        // Verify all boards were saved
        let allBoards = try await repository.searchBoards(
            query: "Concurrent",
            offset: 0,
            limit: 20,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(allBoards.boards.count, 10)
        
        // Test concurrent reads
        await withTaskGroup(of: Board?.self) { group in
            for boardId in boardIds {
                group.addTask {
                    try! await self.repository.load(id: boardId)
                }
            }
            
            var retrievedBoards: [Board?] = []
            for await board in group {
                retrievedBoards.append(board)
            }
            
            XCTAssertEqual(retrievedBoards.count, 10)
            XCTAssertTrue(retrievedBoards.allSatisfy { $0 != nil })
        }
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityConstraints() async throws {
        // Test unique ID constraint (should be handled by the app layer)
        let boardId = UUID()
        let board1 = try Board(
            id: boardId,
            name: "First Board",
            width: 3,
            height: 3,
            cells: [[true, false, true], [false, true, false], [true, false, true]]
        )
        
        try await repository.save(board1)
        
        // Save another board with same ID (should replace, not duplicate)
        let board2 = try Board(
            id: boardId,
            name: "Second Board",
            width: 3,
            height: 3,
            cells: [[false, true, false], [true, false, true], [false, true, false]]
        )
        
        try await repository.save(board2)
        
        // Verify only one board exists with that ID
        let request: NSFetchRequest<BoardEntity> = BoardEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", boardId as CVarArg)
        
        let entities = try context.fetch(request)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.name, "Second Board")
    }
    
    func testCellsDataSerialization() async throws {
        // Test various grid sizes and patterns
        let testCases: [(String, CellsGrid)] = [
            ("Empty Grid", []),
            ("Single Cell Dead", [[false]]),
            ("Single Cell Alive", [[true]]),
            ("Small Grid", [[true, false], [false, true]]),
            ("Large Grid", Array(repeating: Array(repeating: true, count: 100), count: 100)),
            ("Complex Pattern", [
                [true, false, true, false, true],
                [false, true, false, true, false],
                [true, false, false, false, true],
                [false, true, false, true, false],
                [true, false, true, false, true]
            ])
        ]
        
        for (testName, cells) in testCases {
            let width = cells.first?.count ?? 0
            let height = cells.count
            if width == 0 || height == 0 {
                // Empty grids are invalid per Board.validate()
                XCTAssertThrowsError(
                    try Board(
                        id: UUID(),
                        name: testName,
                        width: width,
                        height: height,
                        cells: cells
                    ),
                    "Expected invalidBoardDimensions for empty grid: \(testName)"
                ) { error in
                    XCTAssertEqual(error as? GameError, .invalidBoardDimensions)
                }
                continue
            }

            let board = try Board(
                id: UUID(),
                name: testName,
                width: width,
                height: height,
                cells: cells
            )
            
            try await repository.save(board)
            let retrieved = try await repository.load(id: board.id)
            
            XCTAssertNotNil(retrieved, "Failed to retrieve board for test: \(testName)")
            XCTAssertEqual(retrieved?.cells, cells, "Cell data mismatch for test: \(testName)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() async throws {
        let boardCount = 1000
        let startTime = DispatchTime.now()
        
        // Create large number of boards
        for i in 0..<boardCount {
            let board = try Board(
                id: UUID(),
                name: "Performance Board \(i)",
                width: 10,
                height: 10,
                cells: (0..<10).map { _ in (0..<10).map { _ in Bool.random() } }
            )
            try await repository.save(board)
        }
        
        let createEndTime = DispatchTime.now()
        let createDuration = createEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        
        // Test pagination performance
        let paginationStartTime = DispatchTime.now()
        let firstPage = try await repository.loadBoardsPaginated(
            offset: 0,
            limit: 50,
            sortBy: .createdAtDescending
        )
        let paginationEndTime = DispatchTime.now()
        let paginationDuration = paginationEndTime.uptimeNanoseconds - paginationStartTime.uptimeNanoseconds
        
        // Performance assertions (adjust thresholds based on your requirements)
        XCTAssertLessThan(createDuration, 30_000_000_000) // 30 seconds for 1000 boards
        XCTAssertLessThan(paginationDuration, 1_000_000_000) // 1 second for pagination
        
        XCTAssertEqual(firstPage.boards.count, 50)
        XCTAssertEqual(firstPage.totalCount, boardCount)
        XCTAssertTrue(firstPage.hasMorePages)
        
        print("Created \(boardCount) boards in \(Double(createDuration) / 1_000_000_000)s")
        print("Paginated 50 boards in \(Double(paginationDuration) / 1_000_000_000)s")
    }
    
    // MARK: - Migration and Schema Tests
    
    func testCoreDataModelConsistency() throws {
        let model = context.persistentStoreCoordinator?.managedObjectModel
        XCTAssertNotNil(model)
        
        // Verify Board entity configuration
        guard let boardEntity = model?.entitiesByName["BoardEntity"] else {
            XCTFail("Board entity not found")
            return
        }
        
        // Check required attributes
        let requiredAttributes = [
            ("id", NSAttributeType.UUIDAttributeType),
            ("name", NSAttributeType.stringAttributeType),
            ("width", NSAttributeType.integer16AttributeType),
            ("height", NSAttributeType.integer16AttributeType),
            ("createdAt", NSAttributeType.dateAttributeType),
            ("cellsData", NSAttributeType.binaryDataAttributeType),
            ("currentGeneration", NSAttributeType.integer32AttributeType),
            ("isActive", NSAttributeType.booleanAttributeType),
            ("stateHistoryData", NSAttributeType.binaryDataAttributeType)
        ]
        
        for (attributeName, expectedType) in requiredAttributes {
            guard let attribute = boardEntity.attributesByName[attributeName] else {
                XCTFail("Attribute \(attributeName) not found")
                continue
            }
            XCTAssertEqual(attribute.attributeType, expectedType, "Attribute \(attributeName) has wrong type")
        }
        
        // Verify constraints (note: Core Data constraints are set in the model, not programmatically accessible in tests)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() async throws {
        // Create and immediately release many boards to test memory management
        for i in 0..<100 {
            let board = try Board(
                id: UUID(),
                name: "Memory Test Board \(i)",
                width: 50,
                height: 50,
                cells: (0..<50).map { _ in (0..<50).map { _ in Bool.random() } }
            )
            
            try await repository.save(board)
            
            // Immediately try to retrieve and release
            let retrieved = try await repository.load(id: board.id)
            XCTAssertNotNil(retrieved)
            
            // Force garbage collection periodically
            if i % 10 == 0 {
                try context.save()
                context.reset()
            }
        }
        
        // Final verification
        let allBoards = try await repository.searchBoards(
            query: "Memory Test",
            offset: 0,
            limit: 200,
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(allBoards.boards.count, 100)
    }
}
