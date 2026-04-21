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
enum SearchMatcher {
    static func matches(haystack: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let normalizedHaystack = normalize(haystack)
        let normalizedQuery = normalize(trimmed)
        if !normalizedQuery.isEmpty, normalizedHaystack.contains(normalizedQuery) {
            return true
        }

        if isAllChoseong(trimmed) {
            let projection = choseongProjection(haystack)
            if projection.contains(trimmed) {
                return true
            }
        }

        return false
    }

    // MARK: - Normalization

    static func normalize(_ input: String) -> String {
        let folded = input.precomposedStringWithCompatibilityMapping.lowercased()
        var result = String.UnicodeScalarView()
        result.reserveCapacity(folded.unicodeScalars.count)
        for scalar in folded.unicodeScalars {
            if isStrippedSeparator(scalar) { continue }
            result.append(foldKana(scalar))
        }
        return String(result)
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

    // MARK: - Hangul choseong

    /// Compatibility jamo choseong characters (U+3131..U+314E) mapped to
    /// the 19 choseong indexes used in Hangul syllable composition.
    private static let compatChoseongIndex: [Unicode.Scalar: Int] = [
        "\u{3131}": 0,  "\u{3132}": 1,  "\u{3134}": 2,  "\u{3137}": 3,
        "\u{3138}": 4,  "\u{3139}": 5,  "\u{3141}": 6,  "\u{3142}": 7,
        "\u{3143}": 8,  "\u{3145}": 9,  "\u{3146}": 10, "\u{3147}": 11,
        "\u{3148}": 12, "\u{3149}": 13, "\u{314A}": 14, "\u{314B}": 15,
        "\u{314C}": 16, "\u{314D}": 17, "\u{314E}": 18
    ]

    private static func isAllChoseong(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !scalars.isEmpty else { return false }
        return scalars.allSatisfy { compatChoseongIndex[$0] != nil }
    }

    /// Projects a string to its Hangul choseong characters (compatibility
    /// jamo form). Non-Hangul characters are dropped so the result is a
    /// plain choseong-only string suitable for substring matching.
    private static func choseongProjection(_ input: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in input.unicodeScalars {
            let value = scalar.value
            if value >= 0xAC00 && value <= 0xD7A3 {
                let index = Int((value - 0xAC00) / (21 * 28))
                if let jamo = compatChoseongFromIndex(index) {
                    out.append(jamo)
                }
            } else if compatChoseongIndex[scalar] != nil {
                out.append(scalar)
            }
        }
        return String(out)
    }

    private static let indexToCompatChoseong: [Unicode.Scalar] = [
        "\u{3131}", "\u{3132}", "\u{3134}", "\u{3137}", "\u{3138}",
        "\u{3139}", "\u{3141}", "\u{3142}", "\u{3143}", "\u{3145}",
        "\u{3146}", "\u{3147}", "\u{3148}", "\u{3149}", "\u{314A}",
        "\u{314B}", "\u{314C}", "\u{314D}", "\u{314E}"
    ]

    private static func compatChoseongFromIndex(_ index: Int) -> Unicode.Scalar? {
        guard index >= 0 && index < indexToCompatChoseong.count else { return nil }
        return indexToCompatChoseong[index]
    }
}
