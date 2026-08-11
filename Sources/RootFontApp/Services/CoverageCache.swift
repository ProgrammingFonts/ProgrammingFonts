import Foundation

struct CoverageCache: Sendable {
    private(set) var values: [String: Bool] = [:]
    private var order = LRUOrder<String>()
    private let limit: Int

    init(limit: Int = 2048) {
        self.limit = limit
    }

    mutating func value(for key: String) -> Bool? {
        guard let cached = values[key] else {
            #if DEBUG
            CacheDiagnostics.shared.recordMiss("coverage")
            #endif
            return nil
        }
        #if DEBUG
        CacheDiagnostics.shared.recordHit("coverage")
        #endif
        touch(key)
        return cached
    }

    mutating func store(_ value: Bool, for key: String) {
        values[key] = value
        touch(key)
        trimIfNeeded()
    }

    mutating func merge(_ updates: [String: Bool]) {
        guard !updates.isEmpty else { return }
        for (key, value) in updates {
            values[key] = value
            touch(key)
        }
        trimIfNeeded()
    }

    mutating func clear() {
        values.removeAll(keepingCapacity: true)
        order.clear()
    }

    private mutating func touch(_ key: String) {
        order.touch(key)
    }

    private mutating func trimIfNeeded() {
        var evicted = 0
        while order.count > limit, let key = order.popTail() {
            values.removeValue(forKey: key)
            evicted += 1
        }
        #if DEBUG
        if evicted > 0 {
            CacheDiagnostics.shared.recordEviction("coverage", count: evicted)
        }
        #endif
    }
}
