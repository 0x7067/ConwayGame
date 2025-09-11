import XCTest
import ConwayGameEngine
@testable import ConwayGame

/// Tests focused on pagination behavior using InMemoryBoardRepository for simplicity
/// This avoids complex dependency injection while testing pagination logic
final class PaginationViewModelTests: XCTestCase {
    private var repository: InMemoryBoardRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        repository = InMemoryBoardRepository()
    }
    
    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Pagination Logic Tests
    
    func testPaginationFlowWithLargeDataset() async throws {
        // Create 50 test boards
        let testBoards = try await createTestBoards(count: 50)
        
        // Test first page (20 items)
        let firstPage = try await repository.loadBoardsPaginated(
            offset: 0, 
            limit: 20, 
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(firstPage.boards.count, 20)
        XCTAssertEqual(firstPage.totalCount, 50)
        XCTAssertTrue(firstPage.hasMorePages)
        XCTAssertEqual(firstPage.currentPage, 0)
        XCTAssertEqual(firstPage.pageSize, 20)
        
        // Test second page
        let secondPage = try await repository.loadBoardsPaginated(
            offset: 20, 
            limit: 20, 
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(secondPage.boards.count, 20)
        XCTAssertEqual(secondPage.totalCount, 50)
        XCTAssertTrue(secondPage.hasMorePages)
        XCTAssertEqual(secondPage.currentPage, 1)
        
        // Test third page (partial)
        let thirdPage = try await repository.loadBoardsPaginated(
            offset: 40, 
            limit: 20, 
            sortBy: .createdAtDescending
        )
        
        XCTAssertEqual(thirdPage.boards.count, 10)
        XCTAssertEqual(thirdPage.totalCount, 50)
        XCTAssertFalse(thirdPage.hasMorePages)
        XCTAssertEqual(thirdPage.currentPage, 2)
        
        // Verify no duplicate boards across pages
        let allBoardIds = Set(firstPage.boards.map(\.id) + secondPage.boards.map(\.id) + thirdPage.boards.map(\.id))
        XCTAssertEqual(allBoardIds.count, 50)
    }
    
    func testSearchPaginationFiltersAndPaginatesCorrectly() async throws {
        // Create boards with different names
        let gameBoards = try (0..<15).map { i in
            try Board(name: "Game Board \(i)", width: 5, height: 5, cells: createEmptyCells(width: 5, height: 5))
        }
        let testBoards = try (0..<10).map { i in
            try Board(name: "Test Board \(i)", width: 5, height: 5, cells: createEmptyCells(width: 5, height: 5))
        }
        
        // Save all boards
        for board in gameBoards + testBoards {
            try await repository.save(board)
        }
        
        // Search for "Game" boards with pagination
        let firstPage = try await repository.searchBoards(
            query: "Game",
            offset: 0,
            limit: 10,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(firstPage.boards.count, 10) // First 10 Game boards
        XCTAssertEqual(firstPage.totalCount, 15) // Total Game boards
        XCTAssertTrue(firstPage.hasMorePages)
        
        // All returned boards should contain "Game"
        for board in firstPage.boards {
            XCTAssertTrue(board.name.contains("Game"))
        }
        
        // Get second page
        let secondPage = try await repository.searchBoards(
            query: "Game",
            offset: 10,
            limit: 10,
            sortBy: .nameAscending
        )
        
        XCTAssertEqual(secondPage.boards.count, 5) // Remaining 5 Game boards
        XCTAssertEqual(secondPage.totalCount, 15)
        XCTAssertFalse(secondPage.hasMorePages)
    }
    
    func testSortingBehaviorDifferentOptions() async throws {
        // Create boards with varied creation dates and names
        let boards = try [
            Board(name: "Zebra", width: 5, height: 5, 
                  createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
                  currentGeneration: 10, cells: createEmptyCells(width: 5, height: 5)),
            Board(name: "Alpha", width: 5, height: 5, 
                  createdAt: Date().addingTimeInterval(-1800), // 30 min ago
                  currentGeneration: 5, cells: createEmptyCells(width: 5, height: 5)),
            Board(name: "Beta", width: 5, height: 5, 
                  createdAt: Date(), // now
                  currentGeneration: 15, cells: createEmptyCells(width: 5, height: 5))
        ]
        
        for board in boards {
            try await repository.save(board)
        }
        
        // Test name ascending sort
        let nameAsc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .nameAscending)
        XCTAssertEqual(nameAsc.boards.map(\.name), ["Alpha", "Beta", "Zebra"])
        
        // Test name descending sort
        let nameDesc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .nameDescending)
        XCTAssertEqual(nameDesc.boards.map(\.name), ["Zebra", "Beta", "Alpha"])
        
        // Test creation date descending (newest first)
        let createdDesc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .createdAtDescending)
        XCTAssertEqual(createdDesc.boards.map(\.name), ["Beta", "Alpha", "Zebra"])
        
        // Test generation descending
        let genDesc = try await repository.loadBoardsPaginated(offset: 0, limit: 10, sortBy: .generationDescending)
        XCTAssertEqual(genDesc.boards.map(\.name), ["Beta", "Zebra", "Alpha"]) // 15, 10, 5
    }
    
    // MARK: - Helper Methods
    
    private func createTestBoards(count: Int) async throws -> [Board] {
        var boards: [Board] = []
        for i in 0..<count {
            let createdAt = Date().addingTimeInterval(TimeInterval(i) * 0.001)
            let board = try Board(
                name: "Test Board \(i)",
                width: 3,
                height: 3,
                createdAt: createdAt,
                cells: createEmptyCells(width: 3, height: 3)
            )
            try await repository.save(board)
            boards.append(board)
        }
        return boards
    }
    
    private func createEmptyCells(width: Int = 3, height: Int = 3) -> CellsGrid {
        return Array(repeating: Array(repeating: false, count: width), count: height)
    }
}