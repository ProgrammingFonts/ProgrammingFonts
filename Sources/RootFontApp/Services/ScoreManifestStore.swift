import Foundation

protocol ScoreManifestStoreProtocol: Sendable {
    func load() -> [String: CachedScoreEntry]
    func save(_ entries: [String: CachedScoreEntry])
    func cacheKey(for postScriptName: String, fileURL: URL) -> String
}

struct CachedScoreEntry: Codable, Sendable, Hashable {
    var programming: ProgrammingProfile?
    var metrics: FontMetricsSample?
    var score: ProgrammingScore?
}

struct ScoreManifestStore: ScoreManifestStoreProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let manifestURL: URL
    private let lock = NSLock()
    private var cachedEntries: [String: CachedScoreEntry]?

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
                .appendingPathComponent("RootFont", isDirectory: true)
                .appendingPathComponent("scores.json")
        }
    }

    func load() -> [String: CachedScoreEntry] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedEntries {
            return cachedEntries
        }
        let entries = readEntriesFromDisk()
        cachedEntries = entries
        return entries
    }

    func save(_ entries: [String: CachedScoreEntry]) {
        lock.lock()
        if let cachedEntries, cachedEntries == entries {
            lock.unlock()
            return
        }
        lock.unlock()

        let directory = manifestURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
        lock.lock()
        cachedEntries = entries
        lock.unlock()
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
