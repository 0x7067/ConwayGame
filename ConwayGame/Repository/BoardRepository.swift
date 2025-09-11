import Foundation
import ConwayGameEngine

public protocol BoardRepository {
    func save(_ board: Board) async throws
    func load(id: UUID) async throws -> Board?
    @available(*, deprecated, message: "Use loadBoardsPaginated instead for better performance")
    func loadAll() async throws -> [Board]
    func loadBoardsPaginated(offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage
    func searchBoards(query: String, offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage
    func getTotalBoardCount() async throws -> Int
    func delete(id: UUID) async throws
    func rename(id: UUID, newName: String) async throws
    func reset(id: UUID) async throws -> Board
}

public actor InMemoryBoardRepository: BoardRepository {
    private var storage: [UUID: Board] = [:]

    public init() {}

    public func save(_ board: Board) async throws {
        storage[board.id] = board
    }

    public func load(id: UUID) async throws -> Board? {
        return storage[id]
    }

    public func loadAll() async throws -> [Board] {
        return Array(storage.values)
    }
    
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

    public func delete(id: UUID) async throws {
        storage[id] = nil
    }
    
    public func rename(id: UUID, newName: String) async throws {
        guard var board = storage[id] else {
            throw GameError.boardNotFound(id)
        }
        board.name = newName
        storage[id] = board
    }
    
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

