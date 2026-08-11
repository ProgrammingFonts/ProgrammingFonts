import AppKit
import CoreText
import Foundation
import os

protocol FontCatalogServiceProtocol: Sendable {
    /// Loads the font catalog, streaming partial results and progress as
    /// events. The stream terminates with `.completed` or `.failed`.
    func loadFonts() -> AsyncStream<FontCatalogEvent>
}

/// Events emitted by `FontCatalogService.loadFonts()`.
enum FontCatalogEvent: Sendable {
    /// Initial/partial batch of fonts (pre-enrichment sort snapshot).
    case partial([FontItem])
    /// Progress fraction in `0...1`.
    case progress(Double)
    /// Final fully-enriched font list.
    case completed([FontItem])
    /// Catalog read failed.
    case failed
}

extension FontCatalogServiceProtocol {
    /// Convenience for one-shot callers and tests: drains the event stream
    /// and returns the final font list (or throws on failure).
    func drainFonts() async throws -> [FontItem] {
        for await event in loadFonts() {
            switch event {
            case .completed(let fonts): return fonts
            case .failed: throw FontCatalogService.CatalogError.unableToReadFontCatalog
            default: continue
            }
        }
        throw FontCatalogService.CatalogError.unableToReadFontCatalog
    }
}

struct FontCatalogService: FontCatalogServiceProtocol {
    enum CatalogError: Error {
        case unableToReadFontCatalog
    }

    private let styleResolver: FontStyleResolverProtocol
    private let featureInspector: FontFeatureInspectorProtocol
    private let metricsProbe: FontMetricsProbeProtocol
    private let scoreEngine: ProgrammingScoreEngine
    private let scoreManifestStore: ScoreManifestStoreProtocol
    private let fontURLIndex: FontURLIndex

    init(
        styleResolver: FontStyleResolverProtocol = FontStyleResolver(),
        featureInspector: FontFeatureInspectorProtocol = FontFeatureInspector(),
        metricsProbe: FontMetricsProbeProtocol = FontMetricsProbe(),
        scoreEngine: ProgrammingScoreEngine = ProgrammingScoreEngine(),
        scoreManifestStore: ScoreManifestStoreProtocol = ScoreManifestStore(),
        fontURLIndex: FontURLIndex = .shared
    ) {
        self.styleResolver = styleResolver
        self.featureInspector = featureInspector
        self.metricsProbe = metricsProbe
        self.scoreEngine = scoreEngine
        self.scoreManifestStore = scoreManifestStore
        self.fontURLIndex = fontURLIndex
    }

    func loadFonts() -> AsyncStream<FontCatalogEvent> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await Self.loadFontsImpl(
                    styleResolver: self.styleResolver,
                    featureInspector: self.featureInspector,
                    metricsProbe: self.metricsProbe,
                    scoreEngine: self.scoreEngine,
                    scoreManifestStore: self.scoreManifestStore,
                    fontURLIndex: self.fontURLIndex,
                    yield: { continuation.yield($0) }
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func loadFontsImpl(
        styleResolver: FontStyleResolverProtocol,
        featureInspector: FontFeatureInspectorProtocol,
        metricsProbe: FontMetricsProbeProtocol,
        scoreEngine: ProgrammingScoreEngine,
        scoreManifestStore: ScoreManifestStoreProtocol,
        fontURLIndex: FontURLIndex,
        yield: @Sendable @escaping (FontCatalogEvent) -> Void
    ) async {
        let descriptors = fontURLIndex.urls

        AppLog.catalog.info("loading catalog: \(descriptors.count, privacy: .public) url(s)")

        var seen = Set<String>()
        var items: [FontItem] = []
        var cacheKeyByPostScriptName: [String: String] = [:]
        var pendingEnrichmentIndices: [Int] = []
        let cachedEntries = scoreManifestStore.load()
        items.reserveCapacity(descriptors.count)

        for url in descriptors {
            let postScriptName = url.deletingPathExtension().lastPathComponent
            guard !postScriptName.isEmpty else { continue }
            guard !seen.contains(postScriptName) else { continue }
            seen.insert(postScriptName)

            let cacheKey = scoreManifestStore.cacheKey(for: postScriptName, fileURL: url)
            cacheKeyByPostScriptName[postScriptName] = cacheKey
            let cached = cachedEntries[cacheKey]

            if let cached, let warmItem = cached.fontItem(postScriptName: postScriptName) {
                items.append(warmItem)
                continue
            }

            let nsFont = NSFont(name: postScriptName, size: 16) ?? NSFont.systemFont(ofSize: 16)
            let source: FontSource = url.path.contains("/System/Library/Fonts") ? .system : .user
            let styles = styleResolver.resolveStyleTags(for: nsFont)

            let ctFont = CTFontCreateWithName(postScriptName as CFString, 16, nil)
            let defaultFamily = nsFont.familyName ?? postScriptName
            let defaultDisplay = nsFont.displayName ?? postScriptName
            let localizedFamily = nativeLocalizedName(for: ctFont, nameID: kCTFontFamilyNameKey, fallback: defaultFamily)
            let localizedDisplay = nativeLocalizedName(for: ctFont, nameID: kCTFontFullNameKey, fallback: defaultDisplay)
            let weightTier = cached?.metadata?.weightTier
                ?? FontWeightTierResolver().resolveWeightTier(postScriptName: postScriptName)

            if let cached {
                items.append(
                    FontItem(
                        id: postScriptName,
                        familyName: defaultFamily,
                        postScriptName: postScriptName,
                        displayName: defaultDisplay,
                        source: source,
                        styleTags: styles,
                        localizedFamilyNames: localizedFamily,
                        localizedDisplayNames: localizedDisplay,
                        programming: cached.programming,
                        metrics: cached.metrics,
                        programmingScore: cached.score,
                        weightTier: weightTier
                    )
                )
            } else {
                pendingEnrichmentIndices.append(items.count)
                items.append(
                    FontItem(
                        id: postScriptName,
                        familyName: defaultFamily,
                        postScriptName: postScriptName,
                        displayName: defaultDisplay,
                        source: source,
                        styleTags: styles,
                        localizedFamilyNames: localizedFamily,
                        localizedDisplayNames: localizedDisplay,
                        weightTier: weightTier
                    )
                )
            }
        }

        let partialScored: [FontItem]
        if pendingEnrichmentIndices.isEmpty {
            partialScored = items
        } else {
            AppLog.catalog.info("enriching \(pendingEnrichmentIndices.count, privacy: .public) font(s) in parallel")
            partialScored = Self.attachProgrammingScores(
                items,
                scoreEngine: scoreEngine,
                preservingExistingScores: true
            )
        }
        let partialSorted = partialScored.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }
        yield(.partial(partialSorted))
        yield(.progress(pendingEnrichmentIndices.isEmpty ? 1.0 : 0.35))

        if !pendingEnrichmentIndices.isEmpty {
            let total = pendingEnrichmentIndices.count
            let postScriptNames = items.map(\.postScriptName)
            let workerCount = min(
                ProcessInfo.processInfo.activeProcessorCount,
                max(1, total)
            )

            // Shard pending indices across workers up-front so the
            // task group can fan out in one pass instead of the previous
            // N+1 popFirst handoff that effectively serialized scheduling.
            let shards = Self.shard(pendingEnrichmentIndices, workerCount: workerCount)

            var completed = 0
            await withTaskGroup(of: [(Int, ProgrammingProfile, FontMetricsSample?)].self) { group in
                for shard in shards {
                    group.addTask {
                        var results: [(Int, ProgrammingProfile, FontMetricsSample?)] = []
                        results.reserveCapacity(shard.count)
                        for index in shard {
                            let name = postScriptNames[index]
                            let programming = featureInspector.inspect(postScriptName: name)
                            let metrics = metricsProbe.measure(
                                postScriptName: name,
                                isMonospaced: programming.isMonospaced
                            )
                            results.append((index, programming, metrics))
                        }
                        return results
                    }
                }
                for await batchResults in group {
                    for (index, programming, metrics) in batchResults {
                        items[index].programming = programming
                        items[index].metrics = metrics
                        completed &+= 1
                        let progress = 0.35 + 0.55 * (Double(completed) / Double(total))
                        yield(.progress(progress))
                    }
                }
            }
        }

        if pendingEnrichmentIndices.isEmpty {
            yield(.progress(1.0))
            yield(.completed(partialSorted))
            return
        }

        let coverage = FamilyWeightCoverage.build(from: items)
        let scoredItems = Self.attachProgrammingScores(
            items,
            familyCoverage: coverage,
            scoreEngine: scoreEngine,
            preservingExistingScores: true
        )
        var nextCache = cachedEntries
        for item in scoredItems {
            if let key = cacheKeyByPostScriptName[item.postScriptName] {
                nextCache[key] = CachedScoreEntry.from(item: item)
            }
        }
        scoreManifestStore.save(nextCache)
        yield(.progress(1.0))
        yield(.completed(scoredItems.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }))
    }

    static func attachProgrammingScores(
        _ items: [FontItem],
        familyCoverage: FamilyWeightCoverage? = nil,
        scoreEngine: ProgrammingScoreEngine = ProgrammingScoreEngine(),
        preservingExistingScores: Bool = false
    ) -> [FontItem] {
        let coverage = familyCoverage ?? FamilyWeightCoverage.build(from: items)
        return items.map { item in
            if preservingExistingScores, item.programmingScore != nil {
                return item
            }
            var updated = item
            updated.programmingScore = scoreEngine.score(item: item, familyCoverage: coverage)
            return updated
        }
    }

    /// Splits `indices` into `workerCount` contiguous shards so a
    /// `TaskGroup` can fan out in one pass instead of the previous
    /// popFirst handoff that effectively serialized scheduling.
    private static func shard(_ indices: [Int], workerCount: Int) -> [[Int]] {
        guard workerCount > 0, !indices.isEmpty else { return [] }
        let perWorker = (indices.count + workerCount - 1) / workerCount
        var shards: [[Int]] = []
        shards.reserveCapacity(workerCount)
        var start = indices.startIndex
        while start < indices.endIndex {
            let end = min(start + perWorker, indices.endIndex)
            shards.append(Array(indices[start..<end]))
            start = end
        }
        return shards
    }

    /// Supported app languages we try to bucket localized names into. BCP47
    /// tags match `AppLanguage.rawValue`.
    private static let supportedLanguageTags: [String] = [
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es"
    ]

    /// Returns the font's *native* localized name, keyed by the BCP47 tag
    /// CoreText reports. macOS picks the best-matching name from the
    /// font's own name table based on the current user locale, which for
    /// CJK fonts is typically the font's native locale entry.
    private static func nativeLocalizedName(for font: CTFont, nameID: CFString, fallback: String) -> [String: String] {
        var actualLanguage: Unmanaged<CFString>?
        guard let cfName = CTFontCopyLocalizedName(font, nameID, &actualLanguage) else {
            return [:]
        }
        let name = cfName as String
        guard !name.isEmpty, name != fallback else { return [:] }
        let matched = (actualLanguage?.takeRetainedValue() as String?) ?? ""
        guard let bucket = Self.bucket(for: matched) else { return [:] }
        return [bucket: name]
    }

    /// Maps a raw BCP47/IETF language tag returned by CoreText to one of
    /// our supported app-language buckets.
    private static func bucket(for rawTag: String) -> String? {
        let lower = rawTag.lowercased()
        if lower.hasPrefix("zh") {
            if lower.contains("hans") || lower.contains("cn") || lower.contains("sg") {
                return "zh-Hans"
            }
            if lower.contains("hant") || lower.contains("tw") || lower.contains("hk") || lower.contains("mo") {
                return "zh-Hant"
            }
            return "zh-Hans"
        }
        for tag in supportedLanguageTags where lower.hasPrefix(tag.lowercased()) {
            return tag
        }
        return nil
    }
}
