import Foundation
import os

#if DEBUG
final class CacheDiagnostics: @unchecked Sendable {
    struct Snapshot: Equatable {
        let hits: Int
        let misses: Int
        let evictions: Int
    }

    static let shared = CacheDiagnostics()

    private var lock = os_unfair_lock_s()
    private var counters: [String: (hits: Int, misses: Int, evictions: Int)] = [:]

    func recordHit(_ cache: String) { update(cache) { $0.hits += 1 } }
    func recordMiss(_ cache: String) { update(cache) { $0.misses += 1 } }
    func recordEviction(_ cache: String, count: Int = 1) {
        update(cache) { $0.evictions += count }
    }

    func snapshot(for cache: String) -> Snapshot {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        let value = counters[cache] ?? (0, 0, 0)
        return Snapshot(hits: value.hits, misses: value.misses, evictions: value.evictions)
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        counters.removeAll()
    }

    private func update(
        _ cache: String,
        mutation: (inout (hits: Int, misses: Int, evictions: Int)) -> Void
    ) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        var value = counters[cache] ?? (0, 0, 0)
        mutation(&value)
        counters[cache] = value
    }
}
#endif
