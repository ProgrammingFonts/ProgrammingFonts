import AppKit

/// Shared LRU cache for `NSFont(name:size:)` lookups used by glyph coverage
/// checks and weight-tier resolution.
final class NSFontResolveCache: @unchecked Sendable {
    static let shared = NSFontResolveCache()

    struct CacheKey: Hashable, Sendable {
        let postScriptName: String
        let sizeTenths: Int
    }

    private let cache: LockedLRUCache<CacheKey, NSFont>

    init(limit: Int = 128) {
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
