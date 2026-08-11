import Foundation
import os

protocol ScoreManifestStoreProtocol: Sendable {
    func load() -> [String: CachedScoreEntry]
    @discardableResult func save(_ entries: [String: CachedScoreEntry]) -> Bool
    func cacheKey(for postScriptName: String, fileURL: URL) -> String
}

struct CachedCatalogMetadata: Codable, Sendable, Hashable {
    var familyName: String
    var displayName: String
    var source: FontSource
    var styleTags: Set<FontStyleTag>
    var localizedFamilyNames: [String: String]
    var localizedDisplayNames: [String: String]
    var weightTier: WeightTier?
}

struct CachedScoreEntry: Codable, Sendable, Hashable {
    var programming: ProgrammingProfile?
    var metrics: FontMetricsSample?
    var score: ProgrammingScore?
    /// Static catalog fields captured on save so warm loads can skip CoreText.
    var metadata: CachedCatalogMetadata?

    func fontItem(postScriptName: String) -> FontItem? {
        guard let metadata else { return nil }
        return FontItem(
            id: postScriptName,
            familyName: metadata.familyName,
            postScriptName: postScriptName,
            displayName: metadata.displayName,
            source: metadata.source,
            styleTags: metadata.styleTags,
            localizedFamilyNames: metadata.localizedFamilyNames,
            localizedDisplayNames: metadata.localizedDisplayNames,
            programming: programming,
            metrics: metrics,
            programmingScore: score,
            weightTier: metadata.weightTier
        )
    }

    static func from(item: FontItem) -> CachedScoreEntry {
        let tier = item.weightTier ?? FontWeightTierResolver().resolveWeightTier(postScriptName: item.postScriptName)
        return CachedScoreEntry(
            programming: item.programming,
            metrics: item.metrics,
            score: item.programmingScore,
            metadata: CachedCatalogMetadata(
                familyName: item.familyName,
                displayName: item.displayName,
                source: item.source,
                styleTags: item.styleTags,
                localizedFamilyNames: item.localizedFamilyNames,
                localizedDisplayNames: item.localizedDisplayNames,
                weightTier: tier
            )
        )
    }
}

struct ScoreManifestStore: ScoreManifestStoreProtocol, @unchecked Sendable {
    private final class ScoreMemoryCache: @unchecked Sendable {
        private var lock = os_unfair_lock_s()
        private var entries: [String: CachedScoreEntry]?

        func read() -> [String: CachedScoreEntry]? {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return entries
        }

        func write(_ value: [String: CachedScoreEntry]) {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            entries = value
        }
    }

    /// Current persisted manifest schema version. Bump on breaking
    /// changes to `CachedScoreEntry` / `CachedCatalogMetadata` and add a
    /// migration branch in `readEntriesFromDisk()`.
    static let currentSchemaVersion = 2

    private let fileManager: FileManager
    private let manifestURL: URL
    private let entryCache = ScoreMemoryCache()

    init(
        fileManager: FileManager = .default,
        manifestURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let manifestURL {
            self.manifestURL = manifestURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.manifestURL = appSupport
                .appendingPathComponent("rootfont", isDirectory: true)
                .appendingPathComponent("scores.json")
        }
    }

    func load() -> [String: CachedScoreEntry] {
        if let cachedEntries = entryCache.read() {
            return cachedEntries
        }
        let entries = readEntriesFromDisk()
        entryCache.write(entries)
        return entries
    }

    @discardableResult
    func save(_ entries: [String: CachedScoreEntry]) -> Bool {
        if entryCache.read() == entries {
            return true
        }

        let directory = manifestURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: manifestURL, options: .atomic)
            entryCache.write(entries)
            return true
        } catch {
            AppLog.score.error("score manifest save failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private func readEntriesFromDisk() -> [String: CachedScoreEntry] {
        guard let data = try? Data(contentsOf: manifestURL) else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: CachedScoreEntry].self, from: data)
        } catch {
            AppLog.score.error("score manifest decode failed: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }

    /// Cache key combines PostScript name + file mtime at nanosecond
    /// precision + file size. Sub-second font file replacements (e.g. an
    /// installer overwriting the same path) are detected via the
    /// nanosecond component; size handles same-mtime replacements.
    func cacheKey(for postScriptName: String, fileURL: URL) -> String {
        let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let mtime: TimeInterval
        let size: UInt64
        if let attrs,
           let date = attrs[.modificationDate] as? Date {
            mtime = date.timeIntervalSince1970
        } else {
            mtime = 0
        }
        if let attrs,
           let sizeValue = attrs[.size] as? NSNumber {
            size = sizeValue.uint64Value
        } else {
            size = 0
        }
        let mtimeNanos = Int64((mtime * 1_000_000_000).rounded())
        return "\(postScriptName)|\(mtimeNanos)|\(size)"
    }
}
