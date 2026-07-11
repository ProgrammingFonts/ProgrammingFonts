import Foundation

struct FontSearchPresentation: Sendable, Hashable {
    let primary: String
    let secondary: String
    let primaryHighlightRanges: [Range<Int>]
    let secondaryHighlightRanges: [Range<Int>]
}

enum FontSearchPresentationBuilder {
    static func build(
        for item: FontItem,
        language: AppLanguage,
        preparedQuery: SearchMatcher.PreparedQuery
    ) -> FontSearchPresentation {
        let primaryDefault = item.familyName(for: language)
        let secondaryDefault = item.displayName(for: language)
        guard !preparedQuery.isEmpty else {
            return FontSearchPresentation(
                primary: primaryDefault,
                secondary: secondaryDefault,
                primaryHighlightRanges: [],
                secondaryHighlightRanges: []
            )
        }

        let (primary, secondary) = preferredTitles(
            for: item,
            language: language,
            preparedQuery: preparedQuery,
            primaryDefault: primaryDefault,
            secondaryDefault: secondaryDefault
        )
        return FontSearchPresentation(
            primary: primary,
            secondary: secondary,
            primaryHighlightRanges: SearchMatcher.highlightCharacterRanges(
                haystack: primary,
                preparedQuery: preparedQuery
            ),
            secondaryHighlightRanges: SearchMatcher.highlightCharacterRanges(
                haystack: secondary,
                preparedQuery: preparedQuery
            )
        )
    }

    private static func preferredTitles(
        for item: FontItem,
        language: AppLanguage,
        preparedQuery: SearchMatcher.PreparedQuery,
        primaryDefault: String,
        secondaryDefault: String
    ) -> (String, String) {
        if SearchMatcher.matches(haystack: primaryDefault, preparedQuery: preparedQuery) {
            return (primaryDefault, secondaryDefault)
        }
        if SearchMatcher.matches(haystack: secondaryDefault, preparedQuery: preparedQuery) {
            return (secondaryDefault, primaryDefault)
        }
        if let alias = item.searchableNames.first(where: {
            SearchMatcher.matches(haystack: $0, preparedQuery: preparedQuery)
        }) {
            return (alias, secondaryDefault)
        }
        return (primaryDefault, secondaryDefault)
    }
}
