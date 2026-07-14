import AppKit
import CoreText
import Foundation

protocol FontCatalogServiceProtocol: Sendable {
    func loadFonts(
        onPartial: (@Sendable ([FontItem]) -> Void)?,
        reportProgress: (@Sendable (Double) -> Void)?
    ) throws -> [FontItem]
}

/// Thread-safe collector that gathers per-index font enrichment results produced
/// by concurrent workers, so the shared array can be mutated serially afterwards.
private final class FontEnrichmentCollector: @unchecked Sendable {
    struct Result {
        let programming: ProgrammingProfile
        let metrics: FontMetricsSample?
    }

    private let lock = NSLock()
    private var results: [Int: Result] = [:]
    private var completed = 0

    /// Records a worker's result and returns the overall progress fraction.
    func record(index: Int, programming: ProgrammingProfile, metrics: FontMetricsSample?, total: Int) -> Double {
        lock.lock()
        defer { lock.unlock() }
        results[index] = Result(programming: programming, metrics: metrics)
        completed += 1
        return 0.35 + 0.55 * (Double(completed) / Double(total))
    }

    func snapshot() -> [Int: Result] {
        lock.lock()
        defer { lock.unlock() }
        return results
    }
}

extension FontCatalogServiceProtocol {
    func loadFonts() throws -> [FontItem] {
        try loadFonts(onPartial: nil, reportProgress: nil)
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

    func loadFonts(
        onPartial: (@Sendable ([FontItem]) -> Void)?,
        reportProgress: (@Sendable (Double) -> Void)?
    ) throws -> [FontItem] {
        let descriptors = fontURLIndex.urls

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
            partialScored = Self.attachProgrammingScores(
                items,
                scoreEngine: scoreEngine,
                preservingExistingScores: true
            )
        }
        let partialSorted = partialScored.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }
        onPartial?(partialSorted)
        reportProgress?(pendingEnrichmentIndices.isEmpty ? 1.0 : 0.35)

        if !pendingEnrichmentIndices.isEmpty {
            let total = pendingEnrichmentIndices.count
            let postScriptNames = items.map(\.postScriptName)
            let collector = FontEnrichmentCollector()
            let featureInspector = self.featureInspector
            let metricsProbe = self.metricsProbe
            let workerCount = min(
                ProcessInfo.processInfo.activeProcessorCount,
                max(1, total)
            )
            let semaphore = DispatchSemaphore(value: workerCount)
            let group = DispatchGroup()

            for index in pendingEnrichmentIndices {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    semaphore.wait()
                    defer {
                        semaphore.signal()
                        group.leave()
                    }

                    let postScriptName = postScriptNames[index]
                    let programmingProfile = featureInspector.inspect(postScriptName: postScriptName)
                    let metrics = metricsProbe.measure(
                        postScriptName: postScriptName,
                        isMonospaced: programmingProfile.isMonospaced
                    )

                    let progress = collector.record(
                        index: index,
                        programming: programmingProfile,
                        metrics: metrics,
                        total: total
                    )
                    reportProgress?(progress)
                }
            }
            group.wait()

            for (index, result) in collector.snapshot() {
                items[index].programming = result.programming
                items[index].metrics = result.metrics
            }
        }

        if pendingEnrichmentIndices.isEmpty {
            reportProgress?(1.0)
            return partialSorted
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
        reportProgress?(1.0)
        return scoredItems.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }
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

    /// Supported app languages we try to bucket localized names into. BCP47
    /// tags match `AppLanguage.rawValue`.
    private static let supportedLanguageTags: [String] = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

    /// Returns the font's *native* localized name, keyed by the BCP47 tag
    /// CoreText reports. macOS picks the best-matching name from the
    /// font's own name table based on the current user locale, which for
    /// CJK fonts is typically the font's native locale entry.
    private func nativeLocalizedName(for font: CTFont, nameID: CFString, fallback: String) -> [String: String] {
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
