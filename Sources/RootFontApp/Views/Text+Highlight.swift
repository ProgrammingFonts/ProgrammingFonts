import SwiftUI

extension Text {
    /// Builds a `Text` where substrings matched by `SearchMatcher.highlight`
    /// are rendered bold + accent-colored. The outer font modifier still
    /// applies because we compose `Text` fragments rather than fixing a
    /// font on an `AttributedString`.
    static func highlighted(_ source: String, query: String) -> Text {
        let ranges = SearchMatcher.highlight(haystack: source, query: query)
        guard !ranges.isEmpty else { return Text(source) }

        var result = Text("")
        var cursor = source.startIndex
        for range in ranges {
            if cursor < range.lowerBound {
                result = result + Text(String(source[cursor..<range.lowerBound]))
            }
            result = result
                + Text(String(source[range]))
                    .foregroundColor(.accentColor)
                    .bold()
            cursor = range.upperBound
        }
        if cursor < source.endIndex {
            result = result + Text(String(source[cursor..<source.endIndex]))
        }
        return result
    }
}
