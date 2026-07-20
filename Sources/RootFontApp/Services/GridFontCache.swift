import AppKit

/// LRU cache for grid/list card preview fonts (no OpenType binding).
final class GridFontCache: @unchecked Sendable {
    static let shared = GridFontCache()

    struct CacheKey: Hashable, Sendable {
        let postScriptName: String
        let sizeTenths: Int
    }

    private let cache: LockedLRUCache<CacheKey, NSFont>

    init(limit: Int = 256) {
        self.cache = LockedLRUCache(limit: limit)
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
        if let cached = cache.value(for: key) {
            return cached
        }

        guard let resolved = provider(postScriptName, size) else {
            return nil
        }

        if let cached = cache.value(for: key) {
            return cached
        }
        cache.insert(resolved, for: key)
        return resolved
    }

    func clear() {
        cache.clear()
    }
}
