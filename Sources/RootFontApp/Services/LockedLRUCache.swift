import Foundation
import os

/// Thread-safe LRU cache. Backed by `os_unfair_lock_s` for lower overhead
/// than `NSLock` on the read-heavy hot path (font lookup, glyph
/// coverage, preview rendering). The cached `Value` is not required to
/// be `Sendable` because the lock provides exclusive access.
final class LockedLRUCache<Key: Hashable & Sendable, Value>: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var cache: [Key: Value] = [:]
    private var order = LRUOrder<Key>()
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    private func withLock<R>(_ body: () -> R) -> R {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return body()
    }

    func value(for key: Key) -> Value? {
        withLock { cache[key] }
    }

    func insert(_ value: Value, for key: Key) {
        withLock {
            if cache[key] != nil {
                order.remove(key)
            }
            cache[key] = value
            order.touch(key)
            while order.count > limit, let stale = order.popTail() {
                cache.removeValue(forKey: stale)
            }
        }
    }

    func clear() {
        withLock {
            cache.removeAll(keepingCapacity: true)
            order.clear()
        }
    }
}
