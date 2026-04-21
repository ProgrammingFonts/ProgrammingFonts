import Foundation

/// CJK-friendly substring matcher used by the font search box.
///
/// Matching strategy (any of the following counts as a match):
/// 1. NFKC + lowercase + kana-fold + separator-strip substring match.
///    - Folds full-width to half-width, upper to lower case.
///    - Treats hiragana and katakana as equivalent.
///    - Removes spaces and common separators so "Yu Gothic" matches "yugothic".
/// 2. When the query consists entirely of Hangul compatibility choseong
///    (초성) characters, we also match against the choseong projection
///    of the haystack. e.g. "ㅅㄷ" matches "산돌체".
///
/// The matcher can also return the matching *ranges* of the original
/// haystack for UI highlighting (see `highlight(haystack:query:)`).
enum SearchMatcher {
    struct PreparedQuery {
        let trimmed: String
        let normalized: String
        let choseong: String
        let isChoseongOnly: Bool

        var isEmpty: Bool { trimmed.isEmpty }
    }

    static func matches(haystack: String, query: String) -> Bool {
        !highlight(haystack: haystack, query: query).isEmpty
            || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func prepare(query: String) -> PreparedQuery {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let choseong = trimmed.filter { !$0.isWhitespace }
        return PreparedQuery(
            trimmed: trimmed,
            normalized: normalize(trimmed),
            choseong: choseong,
            isChoseongOnly: isAllChoseong(trimmed)
        )
    }

    /// Returns the ranges (in `haystack`'s native String.Index space) that
    /// matched the query. An empty array means "no match" — unless the
    /// query itself is empty, in which case callers should treat the
    /// haystack as matching but with nothing to highlight.
    static func highlight(haystack: String, query: String) -> [Range<String.Index>] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let range = normalizedRange(in: haystack, query: trimmed) {
            return [range]
        }

        if isAllChoseong(trimmed) {
            if let range = choseongRange(in: haystack, query: trimmed) {
                return [range]
            }
        }

        return []
    }

    // MARK: - Normalized matching with back-mapping

    /// Finds the first substring in `haystack` that — after NFKC+lower+kana
    /// fold+separator strip — contains the normalized query. Returns the
    /// corresponding range in the *original* haystack, or nil.
    private static func normalizedRange(in haystack: String, query: String) -> Range<String.Index>? {
        let haystackMap = normalizeWithMap(haystack)
        let queryNorm = normalize(query)
        guard !queryNorm.isEmpty else { return nil }
        guard let nsRange = haystackMap.normalized.range(of: queryNorm) else { return nil }

        let startOffset = haystackMap.normalized.distance(
            from: haystackMap.normalized.startIndex,
            to: nsRange.lowerBound
        )
        let endOffset = haystackMap.normalized.distance(
            from: haystackMap.normalized.startIndex,
            to: nsRange.upperBound
        )
        guard startOffset < haystackMap.originalIndexes.count, endOffset > 0 else { return nil }
        let startIdx = haystackMap.originalIndexes[startOffset]
        let lastIdx = haystackMap.originalIndexes[endOffset - 1]
        let endIdx = haystack.unicodeScalars.index(after: lastIdx)
        // Convert unicode scalar indexes to String.Index-compatible range
        return startIdx..<endIdx
    }

    /// Canonical normalization used for comparisons.
    static func normalize(_ input: String) -> String {
        normalizeWithMap(input).normalized
    }

    /// Projects Hangul syllables to choseong compatibility jamo and drops
    /// all non-Hangul/non-choseong characters.
    static func choseongProjection(_ input: String) -> String {
        var projection = String.UnicodeScalarView()
        for scalar in input.unicodeScalars {
            let value = scalar.value
            if value >= 0xAC00 && value <= 0xD7A3 {
                let index = Int((value - 0xAC00) / (21 * 28))
                if index >= 0 && index < indexToCompatChoseong.count {
                    projection.append(indexToCompatChoseong[index])
                }
            } else if compatChoseongIndex[scalar] != nil {
                projection.append(scalar)
            }
        }
        return String(projection)
    }

    private struct NormalizedMapping {
        let normalized: String
        /// Same length as `normalized.unicodeScalars`. Each element points
        /// to the originating scalar index in the input string.
        let originalIndexes: [String.Index]
    }

    private static func normalizeWithMap(_ input: String) -> NormalizedMapping {
        var outputScalars = String.UnicodeScalarView()
        var map: [String.Index] = []
        for scalarIdx in input.unicodeScalars.indices {
            let scalar = input.unicodeScalars[scalarIdx]
            let singleFolded = String(scalar).precomposedStringWithCompatibilityMapping.lowercased()
            for normScalar in singleFolded.unicodeScalars {
                if isStrippedSeparator(normScalar) { continue }
                outputScalars.append(foldKana(normScalar))
                map.append(scalarIdx)
            }
        }
        return NormalizedMapping(normalized: String(outputScalars), originalIndexes: map)
    }

    private static func isStrippedSeparator(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return true }
        switch scalar {
        case "-", "_", ".", "·", "・", "/":
            return true
        default:
            return false
        }
    }

    /// Maps katakana (U+30A1..U+30F6) to the corresponding hiragana scalar.
    private static func foldKana(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let value = scalar.value
        if value >= 0x30A1 && value <= 0x30F6 {
            return Unicode.Scalar(value - 0x60) ?? scalar
        }
        return scalar
    }

    // MARK: - Hangul choseong matching

    /// Compatibility jamo choseong characters (U+3131..U+314E) mapped to
    /// the 19 choseong indexes used in Hangul syllable composition.
    private static let compatChoseongIndex: [Unicode.Scalar: Int] = [
        "\u{3131}": 0,  "\u{3132}": 1,  "\u{3134}": 2,  "\u{3137}": 3,
        "\u{3138}": 4,  "\u{3139}": 5,  "\u{3141}": 6,  "\u{3142}": 7,
        "\u{3143}": 8,  "\u{3145}": 9,  "\u{3146}": 10, "\u{3147}": 11,
        "\u{3148}": 12, "\u{3149}": 13, "\u{314A}": 14, "\u{314B}": 15,
        "\u{314C}": 16, "\u{314D}": 17, "\u{314E}": 18
    ]

    private static let indexToCompatChoseong: [Unicode.Scalar] = [
        "\u{3131}", "\u{3132}", "\u{3134}", "\u{3137}", "\u{3138}",
        "\u{3139}", "\u{3141}", "\u{3142}", "\u{3143}", "\u{3145}",
        "\u{3146}", "\u{3147}", "\u{3148}", "\u{3149}", "\u{314A}",
        "\u{314B}", "\u{314C}", "\u{314D}", "\u{314E}"
    ]

    private static func isAllChoseong(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !scalars.isEmpty else { return false }
        return scalars.allSatisfy { compatChoseongIndex[$0] != nil }
    }

    /// Finds a choseong-projection substring match and maps it back to
    /// the original Hangul syllable range in the haystack.
    private static func choseongRange(in haystack: String, query: String) -> Range<String.Index>? {
        var projection = String.UnicodeScalarView()
        var map: [String.Index] = []
        for scalarIdx in haystack.unicodeScalars.indices {
            let scalar = haystack.unicodeScalars[scalarIdx]
            let value = scalar.value
            if value >= 0xAC00 && value <= 0xD7A3 {
                let index = Int((value - 0xAC00) / (21 * 28))
                if index >= 0 && index < indexToCompatChoseong.count {
                    projection.append(indexToCompatChoseong[index])
                    map.append(scalarIdx)
                }
            } else if compatChoseongIndex[scalar] != nil {
                projection.append(scalar)
                map.append(scalarIdx)
            }
        }
        let projectionString = String(projection)
        let trimmedQuery = query.filter { !$0.isWhitespace }
        guard !trimmedQuery.isEmpty,
              let range = projectionString.range(of: trimmedQuery) else { return nil }
        let startOffset = projectionString.distance(from: projectionString.startIndex, to: range.lowerBound)
        let endOffset = projectionString.distance(from: projectionString.startIndex, to: range.upperBound)
        guard startOffset < map.count, endOffset > 0 else { return nil }
        let startIdx = map[startOffset]
        let lastIdx = map[endOffset - 1]
        let endIdx = haystack.unicodeScalars.index(after: lastIdx)
        return startIdx..<endIdx
    }
}
