import Foundation

public protocol BoardRepository {
    func save(_ board: Board) async throws
    func load(id: UUID) async throws -> Board?
    func loadAll() async throws -> [Board]
    func delete(id: UUID) async throws
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
}

