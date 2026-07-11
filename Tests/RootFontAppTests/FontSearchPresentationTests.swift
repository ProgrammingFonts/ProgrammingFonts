import XCTest
@testable import RootFontApp

final class FontSearchPresentationTests: XCTestCase {
    func testBuildsHighlightRangesForMatchingFamilyName() {
        let item = FontItem(
            id: "HelveticaNeue-Bold",
            familyName: "Helvetica Neue",
            postScriptName: "HelveticaNeue-Bold",
            displayName: "Helvetica Neue Bold",
            source: .system,
            styleTags: [.bold]
        )
        let prepared = SearchMatcher.prepare(query: "helvetica")
        let presentation = FontSearchPresentationBuilder.build(
            for: item,
            language: .english,
            preparedQuery: prepared
        )

        XCTAssertEqual(presentation.primary, "Helvetica Neue")
        XCTAssertFalse(presentation.primaryHighlightRanges.isEmpty)
        XCTAssertTrue(presentation.secondaryHighlightRanges.isEmpty)
    }

    func testEmptyQueryProducesNoHighlightRanges() {
        let item = FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular])
        let prepared = SearchMatcher.prepare(query: "")
        let presentation = FontSearchPresentationBuilder.build(
            for: item,
            language: .english,
            preparedQuery: prepared
        )

        XCTAssertEqual(presentation.primary, "Alpha")
        XCTAssertTrue(presentation.primaryHighlightRanges.isEmpty)
        XCTAssertTrue(presentation.secondaryHighlightRanges.isEmpty)
    }
}
