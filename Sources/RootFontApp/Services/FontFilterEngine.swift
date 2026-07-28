import AppKit
import CoreText
import Foundation

/// Pure filter + sort pipeline for the font list.
///
/// Extracted from `FontBrowserViewModel` so it can run off the main
/// actor via `Task.detached`: every input is a Sendable value type and
/// the engine does not touch any @MainActor state.
enum FontFilterEngine {
    struct SearchIndexEntry: Sendable, Hashable {
        let normalizedNames: [String]
        let choseongNames: [String]
    }

    struct Inputs: Sendable {
        let preparedQuery: SearchMatcher.PreparedQuery
        let coverageQuery: String
        let selectedSource: FontSource?
        let selectedStyle: FontStyleTag?
        let sidebarFilter: SidebarFilter
        let sortOption: SortOption
        let language: AppLanguage
        let showSystemAliasFonts: Bool
        let scoreWeights: ScoreWeights
        let managedFontIDs: Set<String>
        let manualCollectionFontIDs: Set<String>?
        let tagFilterFontIDs: Set<String>?
        let fontHealthFontIDs: Set<String>?
        let familyWeightCoverage: FamilyWeightCoverage?
        let coverageSupportCache: [String: Bool]
    }

    struct ComputeOutput: Sendable {
        let fonts: [FontItem]
        let coverageCacheUpdates: [String: Bool]
    }

    static func compute(
        fonts: [FontItem],
        searchIndex: [String: SearchIndexEntry],
        favoriteIDs: Set<String>,
        recentIDs: [String],
        inputs: Inputs
    ) -> ComputeOutput {
        let familyCoverage: FamilyWeightCoverage?
        let scoreEngine: ProgrammingScoreEngine?
        if needsFamilyCoverage(inputs: inputs) {
            familyCoverage = inputs.familyWeightCoverage
                ?? FamilyWeightCoverage.build(from: fonts)
            scoreEngine = ProgrammingScoreEngine(weights: inputs.scoreWeights)
        } else {
            familyCoverage = nil
            scoreEngine = nil
        }
        var coverageCache = inputs.coverageSupportCache
        var coverageCacheUpdates: [String: Bool] = [:]
        let recentIDSet = Set(recentIDs)
        let filtered = fonts.filter { item in
            if let collectionIDs = inputs.manualCollectionFontIDs,
               !collectionIDs.contains(item.id) {
                return false
            }

            if let tagIDs = inputs.tagFilterFontIDs,
               !tagIDs.contains(item.id) {
                return false
            }

            if !inputs.preparedQuery.isEmpty,
               !matches(item: item, index: searchIndex[item.id], query: inputs.preparedQuery) {
                return false
            }

            if let source = inputs.selectedSource, item.source != source {
                return false
            }

            if let style = inputs.selectedStyle, !item.styleTags.contains(style) {
                return false
            }

            if !inputs.coverageQuery.isEmpty {
                let cacheKey = "\(item.postScriptName)|\(inputs.coverageQuery)"
                let supported: Bool
                if let cached = coverageCache[cacheKey] {
                    supported = cached
                } else {
                    supported = fontSupportsAllCharacters(
                        postScriptName: item.postScriptName,
                        text: inputs.coverageQuery
                    )
                    coverageCache[cacheKey] = supported
                    if inputs.coverageSupportCache[cacheKey] != supported {
                        coverageCacheUpdates[cacheKey] = supported
                    }
                }
                if !supported {
                    return false
                }
            }

            switch inputs.sidebarFilter {
            case .all:
                return true
            case .system:
                return item.source == .system
            case .user:
                return item.source == .user
            case .favorites:
                return favoriteIDs.contains(item.id)
            case .recents:
                return recentIDSet.contains(item.id)
            case .recommendedForCode:
                guard let familyCoverage, let scoreEngine else { return false }
                return isRecommendedForCode(item, coverage: familyCoverage, scoreEngine: scoreEngine)
            case .avoidForCode:
                guard let familyCoverage, let scoreEngine else { return false }
                return isAvoidForCode(item, coverage: familyCoverage, scoreEngine: scoreEngine)
            case .managed:
                return inputs.managedFontIDs.contains(item.id)
            case .fontHealth:
                guard let ids = inputs.fontHealthFontIDs else { return false }
                return ids.contains(item.id)
            }
        }

        let presentation = inputs.showSystemAliasFonts
            ? filtered
            : collapseSystemAliasFonts(in: filtered)
        let sorted = sort(
            presentation,
            inputs: inputs,
            recentIDs: recentIDs,
            coverage: familyCoverage,
            scoreEngine: scoreEngine
        )
        return ComputeOutput(fonts: sorted, coverageCacheUpdates: coverageCacheUpdates)
    }

    private static func needsFamilyCoverage(inputs: Inputs) -> Bool {
        switch inputs.sidebarFilter {
        case .recommendedForCode, .avoidForCode:
            return true
        case .recents:
            return false
        default:
            return inputs.sortOption == .programmingFit
        }
    }

    // MARK: Matching

    static func matches(
        item: FontItem,
        index: SearchIndexEntry?,
        query: SearchMatcher.PreparedQuery
    ) -> Bool {
        guard let index else {
            return item.searchableNames.contains {
                SearchMatcher.matches(haystack: $0, query: query.trimmed)
            }
        }
        if index.normalizedNames.contains(where: { $0.contains(query.normalized) }) {
            return true
        }
        if query.isChoseongOnly {
            return index.choseongNames.contains(where: { $0.contains(query.choseong) })
        }
        return false
    }

    // MARK: Sorting

    private static func sort(
        _ fonts: [FontItem],
        inputs: Inputs,
        recentIDs: [String],
        coverage: FamilyWeightCoverage?,
        scoreEngine: ProgrammingScoreEngine?
    ) -> [FontItem] {
        switch inputs.sidebarFilter {
        case .recents:
            let recentOrder = Dictionary(uniqueKeysWithValues: recentIDs.enumerated().map { ($1, $0) })
            return fonts.sorted { lhs, rhs in
                let li = recentOrder[lhs.id] ?? Int.max
                let ri = recentOrder[rhs.id] ?? Int.max
                return li < ri
            }
        default:
            let language = inputs.language
            switch inputs.sortOption {
            case .familyName:
                return fonts.sorted {
                    $0.familyName(for: language)
                        .localizedCaseInsensitiveCompare($1.familyName(for: language))
                        == .orderedAscending
                }
            case .displayName:
                return fonts.sorted {
                    $0.displayName(for: language)
                        .localizedCaseInsensitiveCompare($1.displayName(for: language))
                        == .orderedAscending
                }
            case .programmingFit:
                guard let coverage, let scoreEngine else {
                    return fonts.sorted {
                        $0.familyName(for: language)
                            .localizedCaseInsensitiveCompare($1.familyName(for: language))
                            == .orderedAscending
                    }
                }
                return fonts.sorted { lhs, rhs in
                    let lScore = programmingTotal(for: lhs, coverage: coverage, scoreEngine: scoreEngine)
                    let rScore = programmingTotal(for: rhs, coverage: coverage, scoreEngine: scoreEngine)
                    if lScore == rScore {
                        return lhs.familyName(for: language)
                            .localizedCaseInsensitiveCompare(rhs.familyName(for: language)) == .orderedAscending
                    }
                    return lScore > rScore
                }
            }
        }
    }

    /// Prefer the score attached at catalog load / weight changes; fall back
    /// to a fresh `scoreEngine` pass only when the item has no cached total.
    private static func programmingTotal(
        for item: FontItem,
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
    ) -> Int {
        if let cached = item.programmingScore?.total {
            return cached
        }
        return scoreEngine.score(item: item, familyCoverage: coverage)?.total ?? -1
    }

    private static func isRecommendedForCode(
        _ item: FontItem,
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
    ) -> Bool {
        programmingTotal(for: item, coverage: coverage, scoreEngine: scoreEngine) >= 55
    }

    private static func isAvoidForCode(
        _ item: FontItem,
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
    ) -> Bool {
        programmingTotal(for: item, coverage: coverage, scoreEngine: scoreEngine) < 55
    }

    // MARK: Alias collapsing

    private static func collapseSystemAliasFonts(in fonts: [FontItem]) -> [FontItem] {
        var seen = Set<String>()
        var result: [FontItem] = []
        result.reserveCapacity(fonts.count)
        for item in fonts {
            let key = aliasFoldKey(for: item)
            if seen.insert(key).inserted {
                result.append(item)
            }
        }
        return result
    }

    private static func aliasFoldKey(for item: FontItem) -> String {
        guard isSystemAliasFont(item) else { return item.id }
        return "systemAlias|\(item.familyName.lowercased())|\(primaryStyleTag(for: item).rawValue)"
    }

    private static func isSystemAliasFont(_ item: FontItem) -> Bool {
        guard item.source == .system else { return false }
        let family = item.familyName.lowercased()
        let postScript = item.postScriptName.lowercased()
        return family.contains("applesystemui") || postScript.contains("applesystemui")
    }

    private static func primaryStyleTag(for item: FontItem) -> FontStyleTag {
        if item.styleTags.contains(.bold) { return .bold }
        if item.styleTags.contains(.italic) { return .italic }
        if item.styleTags.contains(.regular) { return .regular }
        return .other
    }

    // MARK: Glyph coverage

    /// CoreText glyph queries are thread-safe. Filter passes snapshot the
    /// MainActor coverage cache via `Inputs.coverageSupportCache`.
    static func fontSupportsAllCharacters(postScriptName: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard let font = NSFontResolveCache.shared.font(postScriptName: postScriptName, size: 16) else { return false }
        let filteredScalars = trimmed.unicodeScalars.filter {
            !$0.properties.isWhitespace && !CharacterSet.controlCharacters.contains($0)
        }
        if filteredScalars.isEmpty { return true }

        let utf16Chars = Array(String(String.UnicodeScalarView(filteredScalars)).utf16)
        var glyphs = Array(repeating: CGGlyph(), count: utf16Chars.count)
        return CTFontGetGlyphsForCharacters(font as CTFont, utf16Chars, &glyphs, utf16Chars.count)
    }
}
