import AppKit
import SwiftUI

/// LRU cache for preview-panel fonts after OpenType feature binding.
final class PreviewFontCache: @unchecked Sendable {
    static let shared = PreviewFontCache()

    struct CacheKey: Hashable, Sendable {
        let postScriptName: String
        let sizeTenths: Int
        let options: OpenTypeFeatureOptions
    }

    private let cache: LockedLRUCache<CacheKey, NSFont>

    init(limit: Int = 64) {
        self.cache = LockedLRUCache(limit: limit)
    }

    func font(
        postScriptName: String,
        size: Double,
        options: OpenTypeFeatureOptions,
        binder: OpenTypeFeatureBinding,
        baseFontProvider: (String, CGFloat) -> NSFont? = { name, pointSize in
            NSFont(name: name, size: pointSize)
        }
    ) -> Font? {
        guard let nsFont = nsFont(
            postScriptName: postScriptName,
            size: size,
            options: options,
            binder: binder,
            baseFontProvider: baseFontProvider
        ) else {
            return nil
        }
        return Font(nsFont)
    }

    func nsFont(
        postScriptName: String,
        size: Double,
        options: OpenTypeFeatureOptions,
        binder: OpenTypeFeatureBinding,
        baseFontProvider: (String, CGFloat) -> NSFont?
    ) -> NSFont? {
        let key = CacheKey(
            postScriptName: postScriptName,
            sizeTenths: Int((size * 10).rounded()),
            options: options
        )
        if let cached = cache.value(for: key) {
            return cached
        }

        guard let baseFont = baseFontProvider(postScriptName, CGFloat(size)) else {
            return nil
        }
        let bound = binder.bind(base: baseFont, options: options)

        if let cached = cache.value(for: key) {
            return cached
        }
        cache.insert(bound, for: key)
        return bound
    }

    func clear() {
        cache.clear()
    }
}
