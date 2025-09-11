import Foundation
import CoreData
import OSLog
import ConwayGameEngine

/// Core Data repository implementation for Board persistence.
/// Uses @unchecked Sendable because NSPersistentContainer is thread-safe when accessed
/// through separate background contexts, as done in this implementation.
final class CoreDataBoardRepository: BoardRepository, @unchecked Sendable {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer = PersistenceController.shared.container) {
        self.container = container
    }

    private func encodeCells(_ cells: CellsGrid) -> Data {
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

    private func decodeCells(data: Data, width: Int, height: Int) -> CellsGrid {
        if width == 0 || height == 0 { return [] }
        let bytes = [UInt8](data)
        var grid = Array(repeating: Array(repeating: false, count: width), count: height)
        var bitIndex = 0
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = bitIndex / 8
                let bitInByte = UInt8(7 - (bitIndex % 8))
                if byteIndex < bytes.count {
                    grid[y][x] = (bytes[byteIndex] & (1 << bitInByte)) != 0
                }
                bitIndex += 1
            }
        }
        return grid
    }

    private func encodeHistory(_ history: [String]) throws -> Data {
        try JSONEncoder().encode(history)
    }
    private func decodeHistory(_ data: Data) throws -> [String] {
        try JSONDecoder().decode([String].self, from: data)
    }

    func save(_ board: Board) async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            fetch.predicate = NSPredicate(format: "id == %@", board.id as CVarArg)
            let existing = try context.fetch(fetch).first
            let entity = existing ?? NSEntityDescription.insertNewObject(forEntityName: "BoardEntity", into: context)
            entity.setValue(board.id, forKey: "id")
            entity.setValue(board.name, forKey: "name")
            entity.setValue(Int16(board.width), forKey: "width")
            entity.setValue(Int16(board.height), forKey: "height")
            entity.setValue(board.createdAt, forKey: "createdAt")
            entity.setValue(Int32(board.currentGeneration), forKey: "currentGeneration")
            entity.setValue(board.isActive, forKey: "isActive")
            entity.setValue(self.encodeCells(board.cells), forKey: "cellsData")
            entity.setValue(self.encodeCells(board.initialCells), forKey: "initialCellsData")
            entity.setValue(try self.encodeHistory(board.stateHistory), forKey: "stateHistoryData")
            do { 
                try context.save() 
                Logger.persistence.info("Saved board \(board.id.uuidString)") 
            } catch { 
                Logger.persistence.error("Save error: \(String(describing: error))")
                throw GameError.persistenceError("Failed to save board data: \(error.localizedDescription)")
            }
        }
    }

    func load(id: UUID) async throws -> Board? {
        let context = container.viewContext
        do {
            return try await context.perform {
                let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
                fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                guard let obj = try context.fetch(fetch).first else { return nil }
                return try self.map(obj)
            }
        } catch {
            if error is GameError {
                throw error
            } else {
                throw GameError.persistenceError("Failed to load board: \(error.localizedDescription)")
            }
        }
    }

    func loadAll() async throws -> [Board] {
        let context = container.viewContext
        do {
            return try await context.perform {
                let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
                let list = try context.fetch(fetch)
                return try list.map(self.map)
            }
        } catch {
            if error is GameError {
                throw error
            } else {
                throw GameError.persistenceError("Failed to load boards: \(error.localizedDescription)")
            }
        }
    }
    
    func loadBoardsPaginated(offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        let context = container.viewContext
        return try await context.perform {
            // Get total count
            let countRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            let totalCount = try context.count(for: countRequest)
            
            // Get paginated results
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            fetch.fetchLimit = limit
            fetch.fetchOffset = offset
            fetch.sortDescriptors = sortBy.sortDescriptors
            
            let list = try context.fetch(fetch)
            let boards = try list.map(self.map)
            
            let hasMorePages = (offset + limit) < totalCount
            let currentPage = offset / limit
            
            return BoardListPage(
                boards: boards,
                totalCount: totalCount,
                hasMorePages: hasMorePages,
                currentPage: currentPage,
                pageSize: limit
            )
        }
    }
    
    func searchBoards(query: String, offset: Int, limit: Int, sortBy: BoardSortOption) async throws -> BoardListPage {
        let context = container.viewContext
        return try await context.perform {
            let predicate = query.isEmpty ? nil : NSPredicate(format: "name CONTAINS[cd] %@", query)
            
            // Get total count for search
            let countRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            countRequest.predicate = predicate
            let totalCount = try context.count(for: countRequest)
            
            // Get paginated search results
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            fetch.predicate = predicate
            fetch.fetchLimit = limit
            fetch.fetchOffset = offset
            fetch.sortDescriptors = sortBy.sortDescriptors
            
            let list = try context.fetch(fetch)
            let boards = try list.map(self.map)
            
            let hasMorePages = (offset + limit) < totalCount
            let currentPage = offset / limit
            
            return BoardListPage(
                boards: boards,
                totalCount: totalCount,
                hasMorePages: hasMorePages,
                currentPage: currentPage,
                pageSize: limit
            )
        }
    }
    
    func getTotalBoardCount() async throws -> Int {
        let context = container.viewContext
        return try await context.perform {
            let countRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            return try context.count(for: countRequest)
        }
    }

    func delete(id: UUID) async throws {
        let context = container.newBackgroundContext()
        do {
            try await context.perform {
                let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
                fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                let list = try context.fetch(fetch)
                for obj in list { context.delete(obj) }
                try context.save()
            }
        } catch {
            throw GameError.persistenceError("Failed to delete board: \(error.localizedDescription)")
        }
    }

    func rename(id: UUID, newName: String) async throws {
        guard var board = try await load(id: id) else {
            throw GameError.boardNotFound(id)
        }
        board.name = newName
        try await save(board)
    }
    
    func reset(id: UUID) async throws -> Board {
        guard var board = try await load(id: id) else {
            throw GameError.boardNotFound(id)
        }
        board.cells = board.initialCells
        board.currentGeneration = 0
        board.stateHistory = [BoardHashing.hash(for: board.initialCells)]
        try await save(board)
        return board
    }
    
    private func map(_ obj: NSManagedObject) throws -> Board {
        guard let id = obj.value(forKey: "id") as? UUID,
              let name = obj.value(forKey: "name") as? String,
              let width = obj.value(forKey: "width") as? Int16,
              let height = obj.value(forKey: "height") as? Int16,
              let createdAt = obj.value(forKey: "createdAt") as? Date,
              let currentGeneration = obj.value(forKey: "currentGeneration") as? Int32,
              let isActive = obj.value(forKey: "isActive") as? Bool,
              let cellsData = obj.value(forKey: "cellsData") as? Data,
              let historyData = obj.value(forKey: "stateHistoryData") as? Data else {
            throw GameError.persistenceError("Invalid data in Core Data entity")
        }
        
        let cells = decodeCells(data: cellsData, width: Int(width), height: Int(height))
        let initialCellsData = (obj.value(forKey: "initialCellsData") as? Data) ?? cellsData
        let initialCells = decodeCells(data: initialCellsData, width: Int(width), height: Int(height))
        let history = try decodeHistory(historyData)
        
        return try Board(id: id, name: name, width: Int(width), height: Int(height), 
                        createdAt: createdAt, currentGeneration: Int(currentGeneration), 
                        cells: cells, initialCells: initialCells, isActive: isActive, 
                        stateHistory: history)
    }
}
