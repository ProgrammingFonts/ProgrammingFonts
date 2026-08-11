import CoreText
import Foundation
import os

/// Shared cache of `CTFontManagerCopyAvailableFontURLs` results.
final class FontURLIndex: @unchecked Sendable {
    static let shared = FontURLIndex()

    private var lock = os_unfair_lock_s()
    private var cachedURLs: [URL]?
    private var cachedURLByPostScriptName: [String: URL]?

    private init() {}

    /// Seeds a fixed URL list for unit tests without touching CoreText.
    init(prefetchedURLs: [URL]) {
        cachedURLs = prefetchedURLs
        cachedURLByPostScriptName = Self.buildIndex(from: prefetchedURLs)
    }

    var urls: [URL] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if let cachedURLs {
            return cachedURLs
        }
        let urls = (CTFontManagerCopyAvailableFontURLs() as? [URL]) ?? []
        cachedURLs = urls
        cachedURLByPostScriptName = Self.buildIndex(from: urls)
        return urls
    }

    func url(forPostScriptName postScriptName: String) -> URL? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        if cachedURLByPostScriptName == nil {
            let urls = (CTFontManagerCopyAvailableFontURLs() as? [URL]) ?? []
            cachedURLs = urls
            cachedURLByPostScriptName = Self.buildIndex(from: urls)
        }
        return cachedURLByPostScriptName?[postScriptName]
    }

    func invalidate() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        cachedURLs = nil
        cachedURLByPostScriptName = nil
    }

    private static func buildIndex(from urls: [URL]) -> [String: URL] {
        var index: [String: URL] = [:]
        index.reserveCapacity(urls.count)
        for url in urls {
            let postScriptName = url.deletingPathExtension().lastPathComponent
            guard !postScriptName.isEmpty else { continue }
            index[postScriptName] = url
        }
        return index
    }
}

enum FontURLResolver {
    static func url(forPostScriptName postScriptName: String) -> URL? {
        FontURLIndex.shared.url(forPostScriptName: postScriptName)
    }
}
