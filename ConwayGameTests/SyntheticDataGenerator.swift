import Foundation
import ConwayGameEngine
@testable import ConwayGame

/// Utility for generating synthetic test data to evaluate Core Data scaling performance
final class SyntheticDataGenerator {
    
    /// Generates a large number of boards for performance testing
    /// - Parameters:
    ///   - count: Number of boards to generate
    ///   - repository: Repository to save boards to
    ///   - progressCallback: Optional callback to track progress (0.0 to 1.0)
    static func generateTestBoards(
        count: Int,
        repository: BoardRepository,
        progressCallback: ((Double) -> Void)? = nil
    ) async throws {
        let batchSize = 100
        let batches = (count + batchSize - 1) / batchSize
        
        for batchIndex in 0..<batches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, count)
            _ = endIndex - startIndex
            
            // Generate batch of boards
            var boards: [Board] = []
            for i in startIndex..<endIndex {
                let board = try createTestBoard(index: i)
                boards.append(board)
            }
            
            // Save batch concurrently
            await withTaskGroup(of: Void.self) { group in
                for board in boards {
                    group.addTask {
                        try? await repository.save(board)
                    }
                }
            }
            
            // Report progress
            let progress = Double(endIndex) / Double(count)
            progressCallback?(progress)
            
            print("Generated batch \(batchIndex + 1)/\(batches): \(endIndex)/\(count) boards")
        }
    }
    
    /// Creates a test board with varied characteristics
    private static func createTestBoard(index: Int) throws -> Board {
        let boardTypes = BoardType.allCases
        let boardType = boardTypes[index % boardTypes.count]
        
        let name = generateBoardName(index: index, type: boardType)
        let (width, height) = generateBoardSize(type: boardType)
        let cells = generateCells(width: width, height: height, type: boardType)
        
        // Vary creation dates to test sorting
        let baseDate = Date().addingTimeInterval(-TimeInterval(index * 3600)) // Spread over hours
        let createdAt = baseDate.addingTimeInterval(Double.random(in: -1800...1800)) // ±30 minutes variation
        
        // Vary generation counts for sorting tests
        let currentGeneration = index % 100
        
        var board = try Board(
            name: name,
            width: width,
            height: height,
            createdAt: createdAt,
            currentGeneration: currentGeneration,
            cells: cells,
            initialCells: cells,
            isActive: Bool.random()
        )
        
        // Add some state history for realistic data
        if currentGeneration > 0 {
            var history: [String] = [BoardHashing.hash(for: cells)]
            for gen in 1...min(currentGeneration, 10) {
                let hashValue = "hash_\(board.id.uuidString.prefix(8))_gen\(gen)"
                history.append(hashValue)
            }
            board.stateHistory = history
        }
        
        return board
    }
    
    /// Generates varied board names for search testing
    private static func generateBoardName(index: Int, type: BoardType) -> String {
        let prefixes = ["Game", "Test", "Conway", "Life", "Cellular", "Pattern", "Board"]
        let suffixes = ["Simulation", "Experiment", "Trial", "Setup", "Configuration", "Demo"]
        let adjectives = ["Advanced", "Simple", "Complex", "Random", "Stable", "Oscillating", "Glider"]
        
        let prefix = prefixes[index % prefixes.count]
        let suffix = suffixes[(index / 7) % suffixes.count]
        let adjective = adjectives[(index / 13) % adjectives.count]
        
        switch index % 5 {
        case 0:
            return "\(prefix) \(type.displayName) #\(index)"
        case 1:
            return "\(adjective) \(type.displayName)"
        case 2:
            return "\(prefix) \(suffix) \(index)"
        case 3:
            return "\(type.displayName) - \(adjective)"
        default:
            return "\(prefix) Board \(index) (\(type.displayName))"
        }
    }
    
    /// Generates varied board sizes
    private static func generateBoardSize(type: BoardType) -> (width: Int, height: Int) {
        switch type {
        case .small:
            let size = Int.random(in: 5...15)
            return (size, size)
        case .medium:
            let width = Int.random(in: 20...40)
            let height = Int.random(in: 20...40)
            return (width, height)
        case .large:
            let width = Int.random(in: 50...100)
            let height = Int.random(in: 50...100)
            return (width, height)
        case .rectangular:
            let isWide = Bool.random()
            if isWide {
                return (Int.random(in: 40...80), Int.random(in: 10...20))
            } else {
                return (Int.random(in: 10...20), Int.random(in: 40...80))
            }
        case .glider:
            return (50, 50) // Standard size for glider patterns
        case .oscillator:
            return (30, 30) // Good size for oscillator patterns
        case .stillLife:
            return (20, 20) // Compact size for still life patterns
        }
    }
    
    /// Generates different types of cell patterns
    private static func generateCells(width: Int, height: Int, type: BoardType) -> CellsGrid {
        var cells = Array(repeating: Array(repeating: false, count: width), count: height)
        
        switch type {
        case .small, .medium, .large, .rectangular:
            // Random pattern with varying density
            let density = Double.random(in: 0.1...0.4)
            for y in 0..<height {
                for x in 0..<width {
                    cells[y][x] = Double.random(in: 0...1) < density
                }
            }
        case .glider:
            // Place a glider pattern if board is large enough
            if width >= 5 && height >= 5 {
                let startX = Int.random(in: 0...(width - 5))
                let startY = Int.random(in: 0...(height - 5))
                cells[startY + 1][startX + 2] = true
                cells[startY + 2][startX + 3] = true
                cells[startY + 3][startX + 1] = true
                cells[startY + 3][startX + 2] = true
                cells[startY + 3][startX + 3] = true
            }
        case .oscillator:
            // Place a blinker pattern
            if width >= 3 && height >= 3 {
                let centerX = width / 2
                let centerY = height / 2
                cells[centerY][centerX - 1] = true
                cells[centerY][centerX] = true
                cells[centerY][centerX + 1] = true
            }
        case .stillLife:
            // Place a block pattern
            if width >= 4 && height >= 4 {
                let startX = width / 2 - 1
                let startY = height / 2 - 1
                cells[startY][startX] = true
                cells[startY][startX + 1] = true
                cells[startY + 1][startX] = true
                cells[startY + 1][startX + 1] = true
            }
        }
        
        return cells
    }
    
    /// Clears all boards from the repository (for cleanup)
    static func clearAllBoards(repository: BoardRepository) async throws {
        let totalCount = try await repository.getTotalBoardCount()
        print("Clearing \(totalCount) boards...")
        
        // Load and delete in batches to avoid memory issues
        let batchSize = 100
        var offset = 0
        
        while offset < totalCount {
            let page = try await repository.loadBoardsPaginated(
                offset: offset,
                limit: batchSize,
                sortBy: .createdAtDescending
            )
            
            await withTaskGroup(of: Void.self) { group in
                for board in page.boards {
                    group.addTask {
                        try? await repository.delete(id: board.id)
                    }
                }
            }
            
            offset += batchSize
            print("Cleared \(min(offset, totalCount))/\(totalCount) boards")
        }
    }
}

// MARK: - Board Types for Testing

enum BoardType: CaseIterable {
    case small
    case medium
    case large
    case rectangular
    case glider
    case oscillator
    case stillLife
    
    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .rectangular:
            return "Rectangular"
        case .glider:
            return "Glider"
        case .oscillator:
            return "Oscillator"
        case .stillLife:
            return "Still Life"
        }
    }
}

// MARK: - Performance Testing Utilities

final class PerformanceTestUtils {
    
    /// Measures the time taken to execute a block of code
    static func measureTime<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> (result: T, timeInterval: TimeInterval) {
        print("Starting: \(operation)")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try await block()
        
        let timeInterval = CFAbsoluteTimeGetCurrent() - startTime
        print("Completed: \(operation) in \(String(format: "%.3f", timeInterval))s")
        
        return (result, timeInterval)
    }
    
    /// Measures memory usage during an operation
    static func measureMemoryUsage<T>(
        operation: String,
        block: () async throws -> T
    ) async rethrows -> (result: T, memoryUsage: UInt64) {
        let startMemory = getCurrentMemoryUsage()
        
        let result = try await block()
        
        let endMemory = getCurrentMemoryUsage()
        // Memory can fluctuate; guard against negative diffs to avoid overflow
        let memoryUsage = endMemory >= startMemory ? (endMemory - startMemory) : 0
        
        print("\(operation) memory usage: \(formatBytes(memoryUsage))")
        
        return (result, memoryUsage)
    }
    
    private static func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
