import Foundation
import CoreData
import OSLog

final class CoreDataBoardRepository: BoardRepository {
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
            entity.setValue(try self.encodeHistory(board.stateHistory), forKey: "stateHistoryData")
            do { try context.save(); Logger.persistence.info("Saved board \(board.id.uuidString)") }
            catch { Logger.persistence.error("Save error: \(String(describing: error))"); throw error }
        }
    }

    func load(id: UUID) async throws -> Board? {
        let context = container.viewContext
        return try await context.perform {
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            guard let obj = try context.fetch(fetch).first else { return nil }
            return try self.map(obj)
        }
    }

    func loadAll() async throws -> [Board] {
        let context = container.viewContext
        return try await context.perform {
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            let list = try context.fetch(fetch)
            return try list.map(self.map)
        }
    }

    func delete(id: UUID) async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            let fetch: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "BoardEntity")
            fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let list = try context.fetch(fetch)
            for obj in list { context.delete(obj) }
            try context.save()
        }
    }

    private func map(_ obj: NSManagedObject) throws -> Board {
        let id = obj.value(forKey: "id") as! UUID
        let name = obj.value(forKey: "name") as! String
        let width = Int(obj.value(forKey: "width") as! Int16)
        let height = Int(obj.value(forKey: "height") as! Int16)
        let createdAt = obj.value(forKey: "createdAt") as! Date
        let currentGeneration = Int(obj.value(forKey: "currentGeneration") as! Int32)
        let isActive = obj.value(forKey: "isActive") as! Bool
        let cellsData = obj.value(forKey: "cellsData") as! Data
        let historyData = obj.value(forKey: "stateHistoryData") as! Data
        let cells = decodeCells(data: cellsData, width: width, height: height)
        let history = try decodeHistory(historyData)
        return try Board(id: id, name: name, width: width, height: height, createdAt: createdAt, currentGeneration: currentGeneration, cells: cells, isActive: isActive, stateHistory: history)
    }
}

