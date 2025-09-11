import Foundation
import ConwayGameEngine

/// Repository protocol for persistent storage and retrieval of Conway Game boards.
///
/// `BoardRepository` provides an abstraction layer for board persistence operations,
/// supporting various storage implementations (Core Data, in-memory, etc.). It includes
/// comprehensive CRUD operations, pagination, search, and batch operations optimized
/// for large datasets.
///
/// ## Core Operations
/// - **CRUD**: Create, read, update, delete board records
/// - **Pagination**: Efficient loading of large board collections  
/// - **Search**: Query boards by name with configurable sorting
/// - **Batch Operations**: Count queries and bulk operations
/// - **Board Management**: Rename and reset board states
///
/// ## Performance Features
/// - Paginated loading for UI scalability
/// - Configurable sorting options (creation date, name, generation)
/// - Search with case-insensitive name matching
/// - Efficient counting operations
///
/// ## Usage Example
/// ```swift
/// let repository: BoardRepository = CoreDataBoardRepository()
/// 
/// // Save a new board
/// try await repository.save(board)
/// 
/// // Load with pagination
/// let page = try await repository.loadBoardsPaginated(
///     offset: 0, limit: 20, sortBy: .createdAtDescending
/// )
/// 
/// // Search boards
/// let results = try await repository.searchBoards(
///     query: "pattern", offset: 0, limit: 10, sortBy: .nameAscending
/// )
/// ```
public protocol BoardRepository {
    /// Persists a board to storage, creating or updating as needed.
    ///
    /// - Parameter board: The board instance to save
    /// - Throws: GameError for persistence failures
    func save(_ board: Board) async throws
    
    /// Loads a board by its unique identifier.
    ///
    /// - Parameter id: UUID of the board to load
    /// - Returns: The board if found, nil if not found
    /// - Throws: GameError for loading failures
    func load(id: UUID) async throws -> Board?
    
    /// Loads all boards from storage.
    ///
    /// - Warning: This method is deprecated for performance reasons.
    ///           Use `loadBoardsPaginated` instead for better scalability.
    /// - Returns: Array of all boards in storage
    /// - Throws: GameError for loading failures
    @available(*, deprecated, message: "Use loadBoardsPaginated instead for better performance")
    func loadAll() async throws -> [Board]
    
    /// Loads boards with pagination and configurable sorting.
    ///
    /// This method provides efficient access to large board collections using
    /// pagination to avoid loading all records into memory simultaneously.
    ///
    /// - Parameters:
    ///   - offset: Number of records to skip (for pagination)
    ///   - limit: Maximum number of records to return
    ///   - sortBy: Sorting criteria (date, name, generation)
    /// - Returns: BoardListPage containing boards, pagination info, and metadata
    /// - Throws: GameError for loading failures
    func loadBoardsPaginated(offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage
    
    /// Searches boards by name with pagination and sorting.
    ///
    /// Performs case-insensitive substring matching on board names,
    /// returning results with the specified sorting and pagination.
    ///
    /// - Parameters:
    ///   - query: Search query string (empty string returns all boards)
    ///   - offset: Number of results to skip
    ///   - limit: Maximum number of results to return  
    ///   - sortBy: Sorting criteria for results
    /// - Returns: BoardListPage with filtered and sorted results
    /// - Throws: GameError for search failures
    func searchBoards(query: String, offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage
    
    /// Gets the total number of boards in storage.
    ///
    /// - Returns: Count of all boards in the repository
    /// - Throws: GameError for counting failures
    func getTotalBoardCount() async throws -> Int
    
    /// Permanently deletes a board from storage.
    ///
    /// - Parameter id: UUID of the board to delete
    /// - Throws: GameError if board not found or deletion fails
    func delete(id: UUID) async throws
    
    /// Updates the display name of a board.
    ///
    /// - Parameters:
    ///   - id: UUID of the board to rename
    ///   - newName: New display name for the board
    /// - Throws: GameError if board not found or rename fails
    func rename(id: UUID, newName: String) async throws
    
    /// Resets a board to its initial state.
    ///
    /// This operation restores the board to generation 0 with its original
    /// cell configuration and clears the state history.
    ///
    /// - Parameter id: UUID of the board to reset
    /// - Returns: The updated board after reset
    /// - Throws: GameError if board not found or reset fails
    func reset(id: UUID) async throws -> Board
}

/// In-memory implementation of BoardRepository for testing and development.
///
/// `InMemoryBoardRepository` provides a thread-safe, memory-based storage implementation
/// that's ideal for unit testing, development, and scenarios where persistence isn't required.
/// As an actor, it ensures thread-safe access to the storage without external locking.
///
/// ## Features
/// - **Thread Safety**: Actor-based concurrency for safe concurrent access
/// - **Full API Support**: Implements all BoardRepository operations
/// - **Efficient Operations**: O(1) lookups, configurable sorting
/// - **Memory Only**: No disk persistence - data lost when process ends
/// - **Testing Friendly**: Clean state, predictable behavior
///
/// ## Use Cases
/// - Unit testing with clean, isolated state
/// - Development and prototyping
/// - Temporary storage scenarios
/// - Performance testing and benchmarks
///
/// ## Limitations
/// - No persistence across app launches
/// - Memory usage grows with number of boards
/// - No transaction support or rollback capabilities
public actor InMemoryBoardRepository: BoardRepository {
    private var storage: [UUID: Board] = [:]

    /// Creates a new in-memory repository with empty storage.
    public init() {}

    /// Stores a board in memory, replacing any existing board with the same ID.
    ///
    /// - Parameter board: The board to store
    /// - Note: This operation is O(1) and thread-safe via actor isolation
    public func save(_ board: Board) async throws {
        storage[board.id] = board
    }

    /// Retrieves a board by ID from memory storage.
    ///
    /// - Parameter id: UUID of the board to retrieve
    /// - Returns: The board if found, nil otherwise
    /// - Note: This operation is O(1) lookup time
    public func load(id: UUID) async throws -> Board? {
        return storage[id]
    }

    /// Returns all boards in storage as an array.
    ///
    /// - Warning: This method is deprecated and may have performance issues
    ///           with large datasets. Use `loadBoardsPaginated` instead.
    /// - Returns: Array containing all stored boards
    /// - Note: Order is not guaranteed without explicit sorting
    public func loadAll() async throws -> [Board] {
        return Array(storage.values)
    }
    
    /// Loads boards with pagination and sorting from memory storage.
    ///
    /// Performs in-memory sorting and pagination, suitable for moderate-sized datasets.
    /// For very large datasets, consider using a persistent storage implementation.
    ///
    /// - Parameters:
    ///   - offset: Number of boards to skip
    ///   - limit: Maximum boards to return  
    ///   - sortBy: Sorting criteria
    /// - Returns: BoardListPage with paginated results and metadata
    public func loadBoardsPaginated(offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        let allBoards = Array(storage.values)
        let sortedBoards = sortBoards(allBoards, by: sortBy)
        let totalCount = sortedBoards.count
        let startIndex = min(offset, totalCount)
        let endIndex = min(offset + limit, totalCount)
        let pageBoards = startIndex < totalCount ? Array(sortedBoards[startIndex..<endIndex]) : []
        let hasMorePages = endIndex < totalCount
        let currentPage = offset / limit
        
        return BoardListPage(
            boards: pageBoards,
            totalCount: totalCount,
            hasMorePages: hasMorePages,
            currentPage: currentPage,
            pageSize: limit
        )
    }
    
    public func searchBoards(query: String, offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        let allBoards = Array(storage.values)
        let filteredBoards = query.isEmpty ? allBoards : allBoards.filter { board in
            board.name.localizedCaseInsensitiveContains(query)
        }
        let sortedBoards = sortBoards(filteredBoards, by: sortBy)
        let totalCount = sortedBoards.count
        let startIndex = min(offset, totalCount)
        let endIndex = min(offset + limit, totalCount)
        let pageBoards = startIndex < totalCount ? Array(sortedBoards[startIndex..<endIndex]) : []
        let hasMorePages = endIndex < totalCount
        let currentPage = offset / limit
        
        return BoardListPage(
            boards: pageBoards,
            totalCount: totalCount,
            hasMorePages: hasMorePages,
            currentPage: currentPage,
            pageSize: limit
        )
    }
    
    public func getTotalBoardCount() async throws -> Int {
        return storage.count
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

    /// Removes a board from memory storage.
    ///
    /// - Parameter id: UUID of the board to delete
    /// - Note: No error is thrown if the board doesn't exist (idempotent operation)
    public func delete(id: UUID) async throws {
        storage[id] = nil
    }
    
    /// Updates the name of a stored board.
    ///
    /// - Parameters:
    ///   - id: UUID of the board to rename
    ///   - newName: New display name for the board
    /// - Throws: GameError.boardNotFound if the board doesn't exist
    public func rename(id: UUID, newName: String) async throws {
        guard var board = storage[id] else {
            throw GameError.boardNotFound(id)
        }
        board.name = newName
        storage[id] = board
    }
    
    /// Resets a board to its initial state.
    ///
    /// Restores the board to generation 0 with original cell configuration
    /// and clears all state history except the initial state hash.
    ///
    /// - Parameter id: UUID of the board to reset
    /// - Returns: The updated board after reset
    /// - Throws: GameError.boardNotFound if the board doesn't exist
    public func reset(id: UUID) async throws -> Board {
        guard var board = storage[id] else {
            throw GameError.boardNotFound(id)
        }
        board.cells = board.initialCells
        board.currentGeneration = 0
        board.stateHistory = [BoardHashing.hash(for: board.initialCells)]
        storage[id] = board
        return board
    }
}

