import AppKit

/// LRU cache for grid/list card preview fonts (no OpenType binding).
final class GridFontCache: @unchecked Sendable {
    static let shared = GridFontCache()

    struct CacheKey: Hashable, Sendable {
        let postScriptName: String
        let sizeTenths: Int
    }

    private let lock = NSLock()
    private var cache: [CacheKey: NSFont] = [:]
    private var order: [CacheKey] = []
    private let limit: Int

    init(limit: Int = 256) {
        self.limit = limit
    }

    func font(
        postScriptName: String,
        size: CGFloat,
        provider: (String, CGFloat) -> NSFont? = { name, pointSize in
            NSFont(name: name, size: pointSize)
        }
    ) -> NSFont? {
        let key = CacheKey(
            postScriptName: postScriptName,
            sizeTenths: Int((size * 10).rounded())
        )
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let resolved = provider(postScriptName, size) else {
            return nil
        }

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        cache[key] = resolved
        order.append(key)
        trimIfNeeded()
        lock.unlock()
        return resolved
    }

    func clear() {
        lock.lock()
        cache.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
        lock.unlock()
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
