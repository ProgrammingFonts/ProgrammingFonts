import Foundation

protocol ScoreManifestStoreProtocol: Sendable {
    func load() -> [String: CachedScoreEntry]
    func save(_ entries: [String: CachedScoreEntry])
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
        private let lock = NSLock()
        private var entries: [String: CachedScoreEntry]?

        func read() -> [String: CachedScoreEntry]? {
            lock.lock()
            defer { lock.unlock() }
            return entries
        }

        func write(_ value: [String: CachedScoreEntry]) {
            lock.lock()
            defer { lock.unlock() }
            entries = value
        }
    }

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

    func save(_ entries: [String: CachedScoreEntry]) {
        if entryCache.read() == entries {
            return
        }

        let directory = manifestURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
        entryCache.write(entries)
    }

    private func readEntriesFromDisk() -> [String: CachedScoreEntry] {
        guard let data = try? Data(contentsOf: manifestURL) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: CachedScoreEntry].self, from: data)) ?? [:]
    }

    func cacheKey(for postScriptName: String, fileURL: URL) -> String {
        let mtime: TimeInterval
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let date = attrs[.modificationDate] as? Date {
            mtime = date.timeIntervalSince1970
        } else {
            mtime = 0
        }
        return "\(postScriptName)|\(Int(mtime))"
    }
}
