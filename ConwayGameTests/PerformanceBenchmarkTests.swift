import XCTest
import ConwayGameEngine
@testable import ConwayGame

/// Performance benchmark tests for Core Data scaling improvements
final class PerformanceBenchmarkTests: XCTestCase {
    private var repository: CoreDataBoardRepository!
    private var inMemoryRepository: InMemoryBoardRepository!
    private var testPersistenceController: PersistenceController!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create isolated in-memory Core Data store for testing
        testPersistenceController = PersistenceController(inMemory: true)
        repository = CoreDataBoardRepository(container: testPersistenceController.container)
        inMemoryRepository = InMemoryBoardRepository()
        
        // Verify repository starts empty for test isolation
        let initialCount = try await repository.getTotalBoardCount()
        XCTAssertEqual(initialCount, 0, "Repository should start empty for each test")
    }
    
    override func tearDown() async throws {
        // Clean up test resources
        repository = nil
        inMemoryRepository = nil
        testPersistenceController = nil
        try await super.tearDown()
    }
    
    // MARK: - Pagination Performance Tests
    
    func testPaginationPerformance_vs_LoadAll() async throws {
        // Generate test data
        print("Generating 1000 test boards...")
        try await SyntheticDataGenerator.generateTestBoards(
            count: 1000,
            repository: repository
        ) { progress in
            if Int(progress * 100) % 10 == 0 {
                print("Progress: \(Int(progress * 100))%")
            }
        }
        
        print("\n=== Performance Comparison: Pagination vs LoadAll ===")
        
        // Benchmark loadAll (deprecated approach)
        let (allBoards, loadAllTime) = try await PerformanceTestUtils.measureTime(
            operation: "loadAll() - Loading 1000 boards"
        ) {
            try await repository.loadAll()
        }
        
        // Benchmark paginated loading (first page)
        let (firstPage, paginatedTime) = try await PerformanceTestUtils.measureTime(
            operation: "loadBoardsPaginated() - Loading first 20 boards"
        ) {
            try await repository.loadBoardsPaginated(offset: 0, limit: 20, sortBy: .createdAtDescending)
        }
        
        print("\nResults:")
        print("- loadAll(): \(String(format: "%.3f", loadAllTime))s for \(allBoards.count) boards")
        print("- loadBoardsPaginated(): \(String(format: "%.3f", paginatedTime))s for \(firstPage.boards.count) boards")
        print("- Performance improvement: \(String(format: "%.1f", loadAllTime / paginatedTime))x faster")
        
        // Verify correctness
        XCTAssertEqual(firstPage.totalCount, 1000)
        XCTAssertEqual(firstPage.boards.count, 20)
        XCTAssertTrue(firstPage.hasMorePages)
        
        // Pagination should be significantly faster
        XCTAssertLessThan(paginatedTime, loadAllTime / 10, "Pagination should be at least 10x faster")
    }
    
    func testMemoryUsage_Pagination_vs_LoadAll() async throws {
        // Generate test data
        try await SyntheticDataGenerator.generateTestBoards(count: 500, repository: repository)
        
        print("\n=== Memory Usage Comparison ===")
        
        // Measure memory usage for loadAll
        let (_, loadAllMemory) = try await PerformanceTestUtils.measureMemoryUsage(
            operation: "loadAll() memory usage"
        ) {
            let boards = try await repository.loadAll()
            // Force retain boards in memory
            return boards.count
        }
        
        // Measure memory usage for pagination
        let (_, paginatedMemory) = try await PerformanceTestUtils.measureMemoryUsage(
            operation: "loadBoardsPaginated() memory usage"
        ) {
            let page = try await repository.loadBoardsPaginated(offset: 0, limit: 20, sortBy: .createdAtDescending)
            return page.boards.count
        }
        
        print("Memory usage comparison:")
        print("- loadAll(): \(loadAllMemory) bytes")
        print("- loadBoardsPaginated(): \(paginatedMemory) bytes")
        
        if loadAllMemory > 0 && paginatedMemory > 0 {
            let memoryReduction = Double(loadAllMemory) / Double(paginatedMemory)
            print("- Memory reduction: \(String(format: "%.1f", memoryReduction))x less memory used")
        }
    }
    
    func testSearchPerformance_WithIndexes() async throws {
        // Generate test data with varied names
        try await SyntheticDataGenerator.generateTestBoards(count: 1000, repository: repository)
        
        print("\n=== Search Performance Test ===")
        
        // Test search performance
        let searchTerms = ["Game", "Test", "Conway", "Large", "Glider"]
        
        for term in searchTerms {
            let (results, searchTime) = try await PerformanceTestUtils.measureTime(
                operation: "Searching for '\(term)'"
            ) {
                try await repository.searchBoards(
                    query: term,
                    offset: 0,
                    limit: 20,
                    sortBy: .nameAscending
                )
            }
            
            print("- '\(term)': \(String(format: "%.3f", searchTime))s, \(results.totalCount) matches, showing \(results.boards.count)")
            
            // Search should be reasonably fast with indexes
            XCTAssertLessThan(searchTime, 1.0, "Search should complete in under 1 second")
        }
    }
    
    func testSortingPerformance_WithIndexes() async throws {
        try await SyntheticDataGenerator.generateTestBoards(count: 1000, repository: repository)
        
        print("\n=== Sorting Performance Test ===")
        
        let sortOptions: [BoardSortOption] = [
            .createdAtDescending,
            .createdAtAscending,
            .nameAscending,
            .nameDescending,
            .generationDescending,
            .generationAscending
        ]
        
        for sortOption in sortOptions {
            let (results, sortTime) = try await PerformanceTestUtils.measureTime(
                operation: "Sorting by \(sortOption.displayName)"
            ) {
                try await repository.loadBoardsPaginated(
                    offset: 0,
                    limit: 20,
                    sortBy: sortOption
                )
            }
            
            print("- \(sortOption.displayName): \(String(format: "%.3f", sortTime))s")
            
            // Verify sorting correctness for first few items
            if results.boards.count >= 2 {
                switch sortOption {
                case .createdAtDescending:
                    XCTAssertGreaterThanOrEqual(results.boards[0].createdAt, results.boards[1].createdAt)
                case .createdAtAscending:
                    XCTAssertLessThanOrEqual(results.boards[0].createdAt, results.boards[1].createdAt)
                case .nameAscending:
                    let comparison = results.boards[0].name.localizedCaseInsensitiveCompare(results.boards[1].name)
                    XCTAssertTrue(comparison == .orderedAscending || comparison == .orderedSame,
                                 "Names should be in ascending order")
                case .nameDescending:
                    let comparison = results.boards[0].name.localizedCaseInsensitiveCompare(results.boards[1].name)
                    XCTAssertTrue(comparison == .orderedDescending || comparison == .orderedSame,
                                 "Names should be in descending order")
                case .generationDescending:
                    XCTAssertGreaterThanOrEqual(results.boards[0].currentGeneration, results.boards[1].currentGeneration)
                case .generationAscending:
                    XCTAssertLessThanOrEqual(results.boards[0].currentGeneration, results.boards[1].currentGeneration)
                }
            }
            
            // Sorting should be fast with indexes
            XCTAssertLessThan(sortTime, 0.5, "Sorting should complete in under 500ms")
        }
    }
    
    func testLargeDatasetPagination() async throws {
        print("\n=== Large Dataset Pagination Test ===")
        
        // Generate a large dataset
        let boardCount = 2000
        try await SyntheticDataGenerator.generateTestBoards(count: boardCount, repository: repository)
        
        // Test pagination through the entire dataset
        let pageSize = 50
        let totalPages = (boardCount + pageSize - 1) / pageSize
        var loadedBoards = 0
        var totalPaginationTime: TimeInterval = 0
        
        for page in 0..<totalPages {
            let offset = page * pageSize
            
            let (results, pageTime) = try await PerformanceTestUtils.measureTime(
                operation: "Loading page \(page + 1)/\(totalPages)"
            ) {
                try await repository.loadBoardsPaginated(
                    offset: offset,
                    limit: pageSize,
                    sortBy: .createdAtDescending
                )
            }
            
            loadedBoards += results.boards.count
            totalPaginationTime += pageTime
            
            // Verify pagination metadata
            XCTAssertEqual(results.totalCount, boardCount)
            XCTAssertEqual(results.currentPage, page)
            XCTAssertEqual(results.pageSize, pageSize)
            
            if page < totalPages - 1 {
                XCTAssertTrue(results.hasMorePages)
                XCTAssertEqual(results.boards.count, pageSize)
            } else {
                XCTAssertFalse(results.hasMorePages)
            }
            
            // Each page should load quickly
            XCTAssertLessThan(pageTime, 0.5, "Each page should load in under 500ms")
        }
        
        print("Pagination Summary:")
        print("- Total boards: \(boardCount)")
        print("- Pages loaded: \(totalPages)")
        print("- Boards retrieved: \(loadedBoards)")
        print("- Total time: \(String(format: "%.3f", totalPaginationTime))s")
        print("- Average time per page: \(String(format: "%.3f", totalPaginationTime / Double(totalPages)))s")
        
        XCTAssertEqual(loadedBoards, boardCount)
    }
    
    func testConcurrentPaginationRequests() async throws {
        try await SyntheticDataGenerator.generateTestBoards(count: 500, repository: repository)
        
        print("\n=== Concurrent Pagination Test ===")
        
        let (_, concurrentTime) = await PerformanceTestUtils.measureTime(
            operation: "10 concurrent pagination requests"
        ) {
            await withTaskGroup(of: BoardListPage.self) { group in
                // Launch 10 concurrent pagination requests
                for i in 0..<10 {
                    group.addTask {
                        let offset = i * 20
                        return try! await self.repository.loadBoardsPaginated(
                            offset: offset,
                            limit: 20,
                            sortBy: .createdAtDescending
                        )
                    }
                }
                
                var results: [BoardListPage] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
        }
        
        print("Concurrent requests completed in \(String(format: "%.3f", concurrentTime))s")
        
        // Concurrent requests should complete reasonably quickly
        XCTAssertLessThan(concurrentTime, 5.0, "Concurrent requests should complete in under 5 seconds")
    }
    
    func testInMemoryVsCoreDataPerformance() async throws {
        print("\n=== In-Memory vs Core Data Performance Comparison ===")
        
        // Generate test boards for both repositories
        let boardCount = 100
        let testBoards = try (0..<boardCount).map { i in
            try Board(
                name: "Test Board \(i)",
                width: 10,
                height: 10,
                createdAt: Date().addingTimeInterval(TimeInterval(i)),
                cells: Array(repeating: Array(repeating: Bool.random(), count: 10), count: 10)
            )
        }
        
        // Populate both repositories
        for board in testBoards {
            try await repository.save(board)
            try await inMemoryRepository.save(board)
        }
        
        // Compare pagination performance
        let (_, coreDataTime) = try await PerformanceTestUtils.measureTime(
            operation: "Core Data pagination"
        ) {
            try await repository.loadBoardsPaginated(offset: 0, limit: 20, sortBy: .createdAtDescending)
        }
        
        let (_, inMemoryTime) = try await PerformanceTestUtils.measureTime(
            operation: "In-Memory pagination"
        ) {
            try await inMemoryRepository.loadBoardsPaginated(offset: 0, limit: 20, sortBy: .createdAtDescending)
        }
        
        print("Performance comparison:")
        print("- Core Data: \(String(format: "%.3f", coreDataTime))s")
        print("- In-Memory: \(String(format: "%.3f", inMemoryTime))s")
        print("- Core Data overhead: \(String(format: "%.1f", coreDataTime / inMemoryTime))x")
        
        // Core Data should be within reasonable performance of in-memory
        XCTAssertLessThan(coreDataTime / inMemoryTime, 10.0, "Core Data should be within 10x of in-memory performance")
    }
    
    // MARK: - Stress Tests
    
    func testStressTest_ContinuousPagination() async throws {
        try await SyntheticDataGenerator.generateTestBoards(count: 1000, repository: repository)
        
        print("\n=== Stress Test: Continuous Pagination ===")
        
        let iterations = 100
        var totalTime: TimeInterval = 0
        var minTime: TimeInterval = .infinity
        var maxTime: TimeInterval = 0
        
        for i in 0..<iterations {
            let randomOffset = Int.random(in: 0...980)
            
            let (_, pageTime) = try await PerformanceTestUtils.measureTime(
                operation: "Stress iteration \(i + 1)"
            ) {
                try await repository.loadBoardsPaginated(
                    offset: randomOffset,
                    limit: 20,
                    sortBy: .createdAtDescending
                )
            }
            
            totalTime += pageTime
            minTime = min(minTime, pageTime)
            maxTime = max(maxTime, pageTime)
        }
        
        let avgTime = totalTime / Double(iterations)
        
        print("Stress test results:")
        print("- Iterations: \(iterations)")
        print("- Average time: \(String(format: "%.3f", avgTime))s")
        print("- Min time: \(String(format: "%.3f", minTime))s")
        print("- Max time: \(String(format: "%.3f", maxTime))s")
        print("- Total time: \(String(format: "%.3f", totalTime))s")
        
        // Performance should be consistent
        XCTAssertLessThan(avgTime, 0.25, "Average pagination time should be under 250ms")
        XCTAssertLessThan(maxTime, avgTime * 10, "Max time should not be more than 10x average")
    }
}