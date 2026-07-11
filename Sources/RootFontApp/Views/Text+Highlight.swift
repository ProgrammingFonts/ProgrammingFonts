import SwiftUI

extension Text {
    /// Builds a `Text` where substrings matched by `SearchMatcher.highlight`
    /// are rendered bold + accent-colored. The outer font modifier still
    /// applies because we compose `Text` fragments rather than fixing a
    /// font on an `AttributedString`.
    static func highlighted(_ source: String, query: String) -> Text {
        highlighted(source, preparedQuery: SearchMatcher.prepare(query: query))
    }

    static func highlighted(_ source: String, preparedQuery: SearchMatcher.PreparedQuery) -> Text {
        guard !preparedQuery.isEmpty else { return Text(source) }
        let ranges = SearchMatcher.highlightCharacterRanges(haystack: source, preparedQuery: preparedQuery)
        return highlighted(source, characterRanges: ranges)
    }

    static func highlighted(_ source: String, characterRanges: [Range<Int>]) -> Text {
        guard !characterRanges.isEmpty else { return Text(source) }

        var result = Text("")
        var cursor = 0
        let sorted = characterRanges.sorted { $0.lowerBound < $1.lowerBound }
        for range in sorted {
            guard range.lowerBound >= cursor, range.upperBound <= source.count else { continue }
            if cursor < range.lowerBound {
                let start = source.index(source.startIndex, offsetBy: cursor)
                let end = source.index(source.startIndex, offsetBy: range.lowerBound)
                result = result + Text(String(source[start..<end]))
            }
            let start = source.index(source.startIndex, offsetBy: range.lowerBound)
            let end = source.index(source.startIndex, offsetBy: range.upperBound)
            result = result
                + Text(String(source[start..<end]))
                    .foregroundColor(.accentColor)
                    .bold()
            cursor = range.upperBound
        }
        if cursor < source.count {
            let start = source.index(source.startIndex, offsetBy: cursor)
            result = result + Text(String(source[start..<source.endIndex]))
        }
        return result
    }
}
