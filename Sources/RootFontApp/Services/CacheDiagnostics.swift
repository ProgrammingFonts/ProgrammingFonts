import Foundation

#if DEBUG
final class CacheDiagnostics: @unchecked Sendable {
    struct Snapshot: Equatable {
        let hits: Int
        let misses: Int
        let evictions: Int
    }

    static let shared = CacheDiagnostics()

    private let lock = NSLock()
    private var counters: [String: (hits: Int, misses: Int, evictions: Int)] = [:]

    func recordHit(_ cache: String) { update(cache) { $0.hits += 1 } }
    func recordMiss(_ cache: String) { update(cache) { $0.misses += 1 } }
    func recordEviction(_ cache: String, count: Int = 1) {
        update(cache) { $0.evictions += count }
    }

    func snapshot(for cache: String) -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        let value = counters[cache] ?? (0, 0, 0)
        return Snapshot(hits: value.hits, misses: value.misses, evictions: value.evictions)
    }

    func reset() {
        lock.lock()
        counters.removeAll()
        lock.unlock()
    }

    private func update(
        _ cache: String,
        mutation: (inout (hits: Int, misses: Int, evictions: Int)) -> Void
    ) {
        lock.lock()
        var value = counters[cache] ?? (0, 0, 0)
        mutation(&value)
        counters[cache] = value
        lock.unlock()
    }
}
#endif
