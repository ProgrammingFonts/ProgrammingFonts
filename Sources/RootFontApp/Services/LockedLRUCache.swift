import Foundation

final class LockedLRUCache<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [Key: Value] = [:]
    private var order: [Key] = []
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    func value(for key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func insert(_ value: Value, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        if cache[key] != nil {
            order.removeAll { $0 == key }
        }
        cache[key] = value
        order.append(key)
        trimIfNeeded()
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    private func trimIfNeeded() {
        guard order.count > limit else { return }
        let overflow = order.count - limit
        for key in order.prefix(overflow) {
            cache.removeValue(forKey: key)
        }
        order.removeFirst(overflow)
    }
}
