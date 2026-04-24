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
        let sidebarFilter: FontBrowserViewModel.SidebarFilter
        let sortOption: FontBrowserViewModel.SortOption
        let language: AppLanguage
        let showSystemAliasFonts: Bool
        let scoreWeights: ScoreWeights
        let managedFontIDs: Set<String>
    }

    static func compute(
        fonts: [FontItem],
        searchIndex: [String: SearchIndexEntry],
        favoriteIDs: Set<String>,
        recentIDs: [String],
        inputs: Inputs
    ) -> [FontItem] {
        let scoreEngine = ProgrammingScoreEngine(weights: inputs.scoreWeights)
        let familyCoverage = FamilyWeightCoverage.build(from: fonts)
        let filtered = fonts.filter { item in
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

            if !inputs.coverageQuery.isEmpty,
               !fontSupportsAllCharacters(
                    postScriptName: item.postScriptName,
                    text: inputs.coverageQuery
               ) {
                return false
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
                return recentIDs.contains(item.id)
            case .recommendedForCode:
                return isRecommendedForCode(item, coverage: familyCoverage, scoreEngine: scoreEngine)
            case .avoidForCode:
                return isAvoidForCode(item, coverage: familyCoverage, scoreEngine: scoreEngine)
            case .managed:
                return inputs.managedFontIDs.contains(item.id)
            }
        }

        let presentation = inputs.showSystemAliasFonts
            ? filtered
            : collapseSystemAliasFonts(in: filtered)
        return sort(
            presentation,
            inputs: inputs,
            recentIDs: recentIDs,
            coverage: familyCoverage,
            scoreEngine: scoreEngine
        )
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
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
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
                return fonts.sorted { lhs, rhs in
                    let lScore = scoreEngine.score(item: lhs, familyCoverage: coverage)?.total ?? -1
                    let rScore = scoreEngine.score(item: rhs, familyCoverage: coverage)?.total ?? -1
                    if lScore == rScore {
                        return lhs.familyName(for: language)
                            .localizedCaseInsensitiveCompare(rhs.familyName(for: language)) == .orderedAscending
                    }
                    return lScore > rScore
                }
            }
        }
    }

    private static func isRecommendedForCode(
        _ item: FontItem,
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
    ) -> Bool {
        guard let score = scoreEngine.score(item: item, familyCoverage: coverage) else { return false }
        return score.total >= 55
    }

    private static func isAvoidForCode(
        _ item: FontItem,
        coverage: FamilyWeightCoverage,
        scoreEngine: ProgrammingScoreEngine
    ) -> Bool {
        guard let score = scoreEngine.score(item: item, familyCoverage: coverage) else { return true }
        return score.total < 55
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

    /// Thread-safe coverage check — intentionally does NOT consult the
    /// MainActor-bound coverage cache, which keeps this function usable
    /// from detached tasks. CoreText glyph queries are thread-safe.
    static func fontSupportsAllCharacters(postScriptName: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard let font = NSFont(name: postScriptName, size: 16) else { return false }
        let filteredScalars = trimmed.unicodeScalars.filter {
            !$0.properties.isWhitespace && !CharacterSet.controlCharacters.contains($0)
        }
        if filteredScalars.isEmpty { return true }

        let utf16Chars = Array(String(String.UnicodeScalarView(filteredScalars)).utf16)
        var glyphs = Array(repeating: CGGlyph(), count: utf16Chars.count)
        return CTFontGetGlyphsForCharacters(font as CTFont, utf16Chars, &glyphs, utf16Chars.count)
    }
}
