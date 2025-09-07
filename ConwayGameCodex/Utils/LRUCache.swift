import Foundation

actor LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var store: [Key: Value] = [:]
    private var order: [Key] = []

    init(capacity: Int) { self.capacity = max(1, capacity) }

    func get(_ key: Key) -> Value? {
        if let value = store[key] {
            // move to back (most recently used)
            if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
            order.append(key)
            return value
        }
        return nil
    }

    func set(_ key: Key, value: Value) {
        if store[key] == nil { order.append(key) }
        store[key] = value
        if order.count > capacity, let evict = order.first {
            order.removeFirst()
            store.removeValue(forKey: evict)
        }
    }

    func clear() { store.removeAll(); order.removeAll() }
}

