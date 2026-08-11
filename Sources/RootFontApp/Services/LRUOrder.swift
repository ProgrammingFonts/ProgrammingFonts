import Foundation

/// O(1) doubly-linked-list LRU ordering backed by a dictionary of nodes.
///
/// Used by caches (`CoverageCache`, `FontSearchPresentationCache`,
/// `LockedLRUCache`) to avoid the O(n) `order.removeAll { $0 == key }`
/// pattern that dominated the hot path on every read/touch.
struct LRUOrder<Key: Hashable & Sendable>: Sendable {
    private var nodes: [Key: Node] = [:]
    private(set) var head: Key? = nil
    private(set) var tail: Key? = nil

    private struct Node: Sendable {
        var prev: Key?
        var next: Key?
    }

    /// Number of keys currently tracked in the ordering.
    var count: Int { nodes.count }

    /// Moves `key` to the most-recently-used position (head). O(1).
    /// If the key is new, it is inserted at the head.
    mutating func touch(_ key: Key) {
        if let node = nodes[key] {
            detach(key, node: node)
        }
        nodes[key] = Node(prev: nil, next: head)
        if let oldHead = head {
            nodes[oldHead]?.prev = key
        }
        head = key
        if tail == nil { tail = key }
    }

    /// Removes `key` from the ordering entirely. O(1). No-op if absent.
    mutating func remove(_ key: Key) {
        guard let node = nodes[key] else { return }
        detach(key, node: node)
    }

    /// Returns and removes the least-recently-used key (tail). O(1).
    @discardableResult
    mutating func popTail() -> Key? {
        guard let key = tail else { return nil }
        remove(key)
        return key
    }

    /// True if `key` is currently tracked.
    func contains(_ key: Key) -> Bool { nodes[key] != nil }

    /// Removes all entries. O(n).
    mutating func clear() {
        nodes.removeAll(keepingCapacity: true)
        head = nil
        tail = nil
    }

    private mutating func detach(_ key: Key, node: Node) {
        if let prev = node.prev {
            nodes[prev]?.next = node.next
        } else {
            head = node.next
        }
        if let next = node.next {
            nodes[next]?.prev = node.prev
        } else {
            tail = node.prev
        }
        nodes.removeValue(forKey: key)
    }
}
