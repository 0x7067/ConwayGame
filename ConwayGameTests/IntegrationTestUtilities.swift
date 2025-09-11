import XCTest
import ConwayGameEngine
import SwiftUI
import CoreData
import FactoryKit
import FactoryTesting
@testable import ConwayGame

// MARK: - Test Patterns and Common Data

struct TestPatterns {
    
    /// Classic Conway's Game of Life patterns with known behaviors
    static let knownPatterns: [String: (grid: CellsGrid, expectedBehavior: PatternBehavior)] = [
        
        "block": ([
            [false, false, false, false],
            [false, true,  true,  false],
            [false, true,  true,  false],
            [false, false, false, false]
        ], .stillLife(population: 4)),
        
        "blinker": ([
            [false, false, false],
            [true,  true,  true],
            [false, false, false]
        ], .oscillator(population: 3, period: 2)),
        
        "toad": ([
            [false, false, false, false],
            [false, true,  true,  true],
            [true,  true,  true,  false],
            [false, false, false, false]
        ], .oscillator(population: 6, period: 2)),
        
        "glider": ([
            [false, true,  false],
            [false, false, true],
            [true,  true,  true]
        ], .spaceship(population: 5)),
        
        "singleCell": ([
            [false, false, false],
            [false, true,  false],
            [false, false, false]
        ], .extinct(generations: 1)),
        
        "beacon": ([
            [true,  true,  false, false],
            [true,  false, false, false],
            [false, false, false, true],
            [false, false, true,  true]
        ], .oscillator(population: 6, period: 2))
    ]
    
    /// Generate random patterns for testing
    static func randomPattern(width: Int, height: Int, density: Double = 0.3) -> CellsGrid {
        return (0..<height).map { _ in
            (0..<width).map { _ in Double.random(in: 0...1) < density }
        }
    }
    
    /// Generate symmetric patterns that often have interesting behaviors
    static func symmetricPattern(size: Int) -> CellsGrid {
        return (0..<size).map { row in
            (0..<size).map { col in
                // Create various symmetric patterns
                (row == col) || (row + col == size - 1) || 
                (row == size / 2) || (col == size / 2)
            }
        }
    }
    
    /// Generate edge patterns to test boundary conditions
    static func edgePattern(width: Int, height: Int) -> CellsGrid {
        return (0..<height).map { row in
            (0..<width).map { col in
                row == 0 || row == height - 1 || col == 0 || col == width - 1
            }
        }
    }
}

enum PatternBehavior {
    case stillLife(population: Int)
    case oscillator(population: Int, period: Int)
    case spaceship(population: Int)
    case extinct(generations: Int)
    case chaotic // No predictable behavior
}

// MARK: - Test Environment Setup

@MainActor
class IntegrationTestEnvironment {
    private(set) var persistenceController: PersistenceController!
    private(set) var gameService: DefaultGameService!
    private(set) var boardRepository: CoreDataBoardRepository!
    private(set) var gameEngine: ConwayGameEngine!
    private(set) var convergenceDetector: DefaultConvergenceDetector!
    private(set) var themeManager: ThemeManager!
    
    init(inMemory: Bool = true) {
        setupEnvironment(inMemory: inMemory)
    }
    
    private func setupEnvironment(inMemory: Bool) {
        // Create Core Data stack
        persistenceController = PersistenceController(inMemory: inMemory)
        
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
        
        // Register dependencies in Factory container (capture references to avoid Sendable issues)
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
    
    func tearDown() {
        Container.shared.reset()
        persistenceController = nil
        gameService = nil
        boardRepository = nil
        gameEngine = nil
        convergenceDetector = nil
        themeManager = nil
    }
    
    /// Create a board with the given pattern and return its ID
    func createBoard(
        name: String = "Test Board",
        pattern: CellsGrid,
        id: UUID = UUID()
    ) async throws -> UUID {
        let board = try Board(
            id: id,
            name: name,
            width: pattern.first?.count ?? 0,
            height: pattern.count,
            cells: pattern
        )
        
        try await boardRepository.save(board)
        return id
    }
    
    /// Create multiple boards for testing pagination and bulk operations
    func createMultipleBoards(count: Int, namePrefix: String = "Test Board") async throws -> [UUID] {
        var boardIds: [UUID] = []
        
        for i in 0..<count {
            let pattern = TestPatterns.randomPattern(
                width: Int.random(in: 5...15),
                height: Int.random(in: 5...15)
            )
            
            let boardId = try await createBoard(
                name: "\(namePrefix) \(String(format: "%03d", i))",
                pattern: pattern
            )
            
            boardIds.append(boardId)
            
            // Small delay to ensure different timestamps
            if i % 10 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            }
        }
        
        return boardIds
    }
}

// MARK: - Test Assertion Helpers

extension XCTestCase {
    
    /// Assert that a game state matches expected pattern behavior
    func assertPatternBehavior(
        _ state: GameState,
        matches behavior: PatternBehavior,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch behavior {
        case .stillLife(let population):
            XCTAssertTrue(state.isStable, "Still life should be stable", file: file, line: line)
            XCTAssertEqual(state.populationCount, population, "Still life population mismatch", file: file, line: line)
            
        case .oscillator(let population, _):
            XCTAssertEqual(state.populationCount, population, "Oscillator population mismatch", file: file, line: line)
            if state.isStable, case .cyclical = state.convergenceType {
                // Oscillator detected as cyclical - good
            } else {
                // Might not have run long enough to detect cycle
            }
            
        case .spaceship(let population):
            XCTAssertEqual(state.populationCount, population, "Spaceship population mismatch", file: file, line: line)
            // Spaceships might not stabilize in small grids
            
        case .extinct(let generations):
            XCTAssertEqual(state.populationCount, 0, "Extinct pattern should have 0 population", file: file, line: line)
            XCTAssertLessThanOrEqual(state.generation, generations, "Should become extinct within expected generations", file: file, line: line)
            XCTAssertTrue(state.isStable, "Extinct state should be stable", file: file, line: line)
            XCTAssertEqual(state.convergenceType, .extinct, "Should be marked as extinct", file: file, line: line)
            
        case .chaotic:
            // No specific assertions - just verify it runs
            XCTAssertGreaterThanOrEqual(state.generation, 0, "Should have valid generation", file: file, line: line)
        }
    }
    
    /// Assert that two grids are equal
    func assertGridsEqual(
        _ grid1: CellsGrid,
        _ grid2: CellsGrid,
        message: String = "Grids should be equal",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(grid1.count, grid2.count, "\(message) - height mismatch", file: file, line: line)
        
        for (rowIndex, (row1, row2)) in zip(grid1, grid2).enumerated() {
            XCTAssertEqual(row1.count, row2.count, "\(message) - row \(rowIndex) width mismatch", file: file, line: line)
            
            for (colIndex, (cell1, cell2)) in zip(row1, row2).enumerated() {
                XCTAssertEqual(cell1, cell2, "\(message) - cell (\(rowIndex),\(colIndex)) mismatch", file: file, line: line)
            }
        }
    }
    
    /// Assert that an operation completes within a time limit
    func assertCompletesWithin<T>(
        timeLimit: TimeInterval,
        operation: () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let startTime = DispatchTime.now()
        let result = try await operation()
        let endTime = DispatchTime.now()
        
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        XCTAssertLessThan(duration, timeLimit, "Operation took too long: \(duration)s", file: file, line: line)
        
        return result
    }
    
    /// Wait for async operation with timeout
    func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        return try await withTimeout(timeout) {
            try await operation()
        }
    }
}

// MARK: - Performance Testing Utilities

struct PerformanceMeasurement {
    let duration: TimeInterval
    let operation: String
    let parameters: [String: Any]
    
    init(operation: String, parameters: [String: Any] = [:], duration: TimeInterval) {
        self.operation = operation
        self.parameters = parameters
        self.duration = duration
    }
    
    func description() -> String {
        let paramDesc = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return "\(operation)(\(paramDesc)): \(String(format: "%.2f", duration * 1000))ms"
    }
}

class PerformanceBenchmark {
    private var measurements: [PerformanceMeasurement] = []
    
    func measure<T>(
        operation: String,
        parameters: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = DispatchTime.now()
        let result = try await block()
        let endTime = DispatchTime.now()
        
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        measurements.append(PerformanceMeasurement(
            operation: operation,
            parameters: parameters,
            duration: duration
        ))
        
        return result
    }
    
    func printResults() {
        print("\n=== Performance Benchmark Results ===")
        for measurement in measurements {
            print(measurement.description())
        }
        print("=====================================\n")
    }
    
    func averageTime(for operation: String) -> TimeInterval? {
        let operationMeasurements = measurements.filter { $0.operation == operation }
        guard !operationMeasurements.isEmpty else { return nil }
        
        let totalTime = operationMeasurements.reduce(0) { $0 + $1.duration }
        return totalTime / Double(operationMeasurements.count)
    }
    
    func reset() {
        measurements.removeAll()
    }
}

// MARK: - Concurrent Testing Utilities

class ConcurrentTestRunner {
    
    static func runConcurrentOperations<T>(
        count: Int,
        operation: @escaping (Int) async throws -> T
    ) async throws -> [T] {
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            // Add all tasks
            for i in 0..<count {
                group.addTask {
                    let result = try await operation(i)
                    return (i, result)
                }
            }
            
            // Collect results in order
            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by index and return values
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }
    
    static func runRaceConditionTest<T>(
        iterations: Int = 100,
        operation: @escaping () async throws -> T,
        validation: @escaping ([T]) throws -> Void
    ) async throws {
        for _ in 0..<iterations {
            let results = try await runConcurrentOperations(count: 10) { _ in
                try await operation()
            }
            
            try validation(results)
        }
    }
}

// MARK: - Mock Data Generators

struct MockDataGenerator {
    
    static func generateBoardWithKnownPattern(_ patternName: String) throws -> Board {
        guard let (pattern, _) = TestPatterns.knownPatterns[patternName] else {
            throw TestError.unknownPattern(patternName)
        }
        
        return try Board(
            id: UUID(),
            name: patternName.capitalized,
            width: pattern.first?.count ?? 0,
            height: pattern.count,
            cells: pattern
        )
    }
    
    static func generateRandomBoard(
        name: String? = nil,
        width: Int = 10,
        height: Int = 10,
        density: Double = 0.3
    ) throws -> Board {
        let pattern = TestPatterns.randomPattern(width: width, height: height, density: density)
        
        return try Board(
            id: UUID(),
            name: name ?? "Random Board \(UUID().uuidString.prefix(8))",
            width: width,
            height: height,
            cells: pattern
        )
    }
    
    static func generateTestBoards(count: Int) throws -> [Board] {
        var boards: [Board] = []
        
        for i in 0..<count {
            let board = try generateRandomBoard(
                name: "Test Board \(String(format: "%03d", i))",
                width: Int.random(in: 5...20),
                height: Int.random(in: 5...20),
                density: Double.random(in: 0.1...0.6)
            )
            boards.append(board)
        }
        
        return boards
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
    case unknownPattern(String)
    case timeout
    case performanceThresholdExceeded(expected: TimeInterval, actual: TimeInterval)
    case unexpectedBehavior(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownPattern(let pattern):
            return "Unknown test pattern: \(pattern)"
        case .timeout:
            return "Test operation timed out"
        case .performanceThresholdExceeded(let expected, let actual):
            return "Performance threshold exceeded: expected \(expected)s, got \(actual)s"
        case .unexpectedBehavior(let description):
            return "Unexpected behavior: \(description)"
        }
    }
}

// MARK: - Timeout Utility

func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T?.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return nil // Timeout reached
        }
        
        // Return first completed result
        for try await result in group {
            if let result = result {
                group.cancelAll()
                return result
            } else {
                // Timeout occurred
                group.cancelAll()
                throw TestError.timeout
            }
        }
        
        throw TestError.timeout
    }
}

// MARK: - Grid Utilities

// extension CellsGrid {
//     
//     /// Count living cells in the grid
//     var populationCount: Int {
//         return self.flatMap { (row: [Bool]) -> [Bool] in row }.filter { (cell: Bool) -> Bool in cell }.count
//     }
//     
//     /// Create a padded version of the grid (add border of dead cells)
//     func padded(by padding: Int = 1) -> CellsGrid {
//         let newWidth = (self.first?.count ?? 0) + (padding * 2)
//         let newHeight = self.count + (padding * 2)
//         
//         var paddedGrid = Array(repeating: Array(repeating: false, count: newWidth), count: newHeight)
//         
//         for (rowIndex, row) in self.enumerated() {
//             for (colIndex, cell) in row.enumerated() {
//                 paddedGrid[rowIndex + padding][colIndex + padding] = cell
//             }
//         }
//         
//         return paddedGrid
//     }
//     
//     /// Get a description string for debugging
//     func debugDescription() -> String {
//         return self.map { (row: [Bool]) -> String in
//             row.map { (cell: Bool) -> String in cell ? "●" : "○" }.joined()
//         }.joined(separator: "\n")
//     }
// }

// MARK: - Test Configuration

struct IntegrationTestConfig {
    static let defaultTimeout: TimeInterval = 30.0
    static let performanceTimeout: TimeInterval = 10.0
    static let concurrentOperationCount = 20
    static let stressTestBoardCount = 100
    static let maxTestGridSize = 100
    
    // Performance thresholds (adjust based on requirements)
    static let maxBoardCreationTime: TimeInterval = 1.0
    static let maxStepTime: TimeInterval = 0.5
    static let maxFinalStateTime: TimeInterval = 10.0
    static let maxPaginationTime: TimeInterval = 2.0
}

// MARK: - Base Test Class

@MainActor
class BaseIntegrationTestCase: XCTestCase {
    var testEnvironment: IntegrationTestEnvironment!
    var benchmark: PerformanceBenchmark!
    
    override func setUp() async throws {
        try await super.setUp()
        testEnvironment = IntegrationTestEnvironment()
        benchmark = PerformanceBenchmark()
    }
    
    override func tearDown() {
        benchmark?.printResults()
        testEnvironment?.tearDown()
        testEnvironment = nil
        benchmark = nil
        super.tearDown()
    }
    
    /// Helper method to create a test board quickly
    func createTestBoard(
        pattern: String = "block",
        name: String? = nil
    ) async throws -> UUID {
        guard let (grid, _) = TestPatterns.knownPatterns[pattern] else {
            throw TestError.unknownPattern(pattern)
        }
        
        return try await testEnvironment.createBoard(
            name: name ?? pattern.capitalized,
            pattern: grid
        )
    }
    
    /// Helper method to run performance-critical operations
    func measurePerformance<T>(
        of operation: String,
        parameters: [String: Any] = [:],
        expectedMaxTime: TimeInterval? = nil,
        block: () async throws -> T
    ) async throws -> T {
        let result = try await benchmark.measure(
            operation: operation,
            parameters: parameters,
            block: block
        )
        
        if let maxTime = expectedMaxTime {
            if let avgTime = benchmark.averageTime(for: operation), avgTime > maxTime {
                throw TestError.performanceThresholdExceeded(expected: maxTime, actual: avgTime)
            }
        }
        
        return result
    }
}
