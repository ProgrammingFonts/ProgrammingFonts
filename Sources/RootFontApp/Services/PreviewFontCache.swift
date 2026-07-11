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

    private let lock = NSLock()
    private var cache: [CacheKey: NSFont] = [:]
    private var order: [CacheKey] = []
    private let limit: Int

    init(limit: Int = 64) {
        self.limit = limit
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
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let baseFont = baseFontProvider(postScriptName, CGFloat(size)) else {
            return nil
        }
        let bound = binder.bind(base: baseFont, options: options)

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        cache[key] = bound
        order.append(key)
        trimIfNeeded()
        lock.unlock()
        return bound
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
