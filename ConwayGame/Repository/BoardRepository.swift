import Foundation
import ConwayGameEngine

public protocol BoardRepository {
    func save(_ board: Board) async throws
    func load(id: UUID) async throws -> Board?
    func loadAll() async throws -> [Board]
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

