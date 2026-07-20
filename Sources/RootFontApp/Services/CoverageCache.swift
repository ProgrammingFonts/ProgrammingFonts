import Foundation

struct CoverageCache: Sendable {
    private(set) var values: [String: Bool] = [:]
    private var order: [String] = []
    private var recentKeys: Set<String> = []
    private let limit: Int

    init(limit: Int = 2048) {
        self.limit = limit
    }

    mutating func value(for key: String) -> Bool? {
        values[key]
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
        order.removeAll(keepingCapacity: true)
        recentKeys.removeAll(keepingCapacity: true)
    }

    private mutating func touch(_ key: String) {
        if recentKeys.contains(key) {
            order.removeAll { $0 == key }
        } else {
            recentKeys.insert(key)
        }
        order.append(key)
    }

    private mutating func trimIfNeeded() {
        guard order.count > limit else { return }
        let overflow = order.count - limit
        guard overflow > 0 else { return }
        for key in order.prefix(overflow) {
            values.removeValue(forKey: key)
            recentKeys.remove(key)
        }
        order.removeFirst(overflow)
    }
}
