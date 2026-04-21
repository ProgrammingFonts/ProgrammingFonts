import XCTest
@testable import RootFontApp

final class SearchMatcherTests: XCTestCase {
    func testEmptyQueryMatchesAnything() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "Hiragino Sans", query: ""))
        XCTAssertTrue(SearchMatcher.matches(haystack: "", query: ""))
    }

    func testCaseInsensitiveAsciiMatch() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "Helvetica Neue", query: "HEL"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "Helvetica Neue", query: "neue"))
    }

    func testFullWidthFoldedToHalfWidth() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "Arial", query: "ＡＲＩＡＬ"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "Arial", query: "ａｒｉａｌ"))
    }

    func testKatakanaHiraganaFold() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "ヒラギノ角ゴシック", query: "ひらぎの"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "ひらぎの", query: "ヒラギノ"))
    }

    func testSeparatorStrippedForRelaxedMatch() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "Yu Gothic Medium", query: "yugothic"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "Apple-SD-Gothic", query: "applesdgothic"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "HiraginoSans-W3", query: "hiragino sans"))
    }

    func testKoreanChoseongMatch() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "산돌체", query: "ㅅㄷ"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "맑은고딕", query: "ㅁㅇ"))
        XCTAssertTrue(SearchMatcher.matches(haystack: "애플 SD 산돌고딕 Neo", query: "ㅅㄷ"))
        XCTAssertFalse(SearchMatcher.matches(haystack: "Arial", query: "ㅅㄷ"))
    }

    func testKoreanExactSyllableStillMatches() {
        XCTAssertTrue(SearchMatcher.matches(haystack: "애플 SD 산돌고딕 Neo", query: "산돌"))
    }

    func testNonMatchingQueryReturnsFalse() {
        XCTAssertFalse(SearchMatcher.matches(haystack: "Helvetica", query: "arial"))
    }

    // MARK: - highlight(...)

    private func substring(_ haystack: String, _ ranges: [Range<String.Index>]) -> [String] {
        ranges.map { String(haystack[$0]) }
    }

    func testHighlightReturnsEmptyForEmptyQuery() {
        XCTAssertTrue(SearchMatcher.highlight(haystack: "Arial", query: "").isEmpty)
        XCTAssertTrue(SearchMatcher.highlight(haystack: "Arial", query: "   ").isEmpty)
    }

    func testHighlightAsciiMatchReturnsOriginalRange() {
        let text = "Helvetica Neue"
        let ranges = SearchMatcher.highlight(haystack: text, query: "neue")
        XCTAssertEqual(substring(text, ranges), ["Neue"])
    }

    func testHighlightKatakanaHiraganaFold() {
        let text = "ヒラギノ角ゴシック"
        let ranges = SearchMatcher.highlight(haystack: text, query: "ひらぎの")
        XCTAssertEqual(substring(text, ranges), ["ヒラギノ"])
    }

    func testHighlightFullWidthToHalfWidth() {
        let text = "Arial"
        let ranges = SearchMatcher.highlight(haystack: text, query: "ＡＲＩ")
        XCTAssertEqual(substring(text, ranges), ["Ari"])
    }

    func testHighlightSeparatorStrippedStillSelectsOriginal() {
        let text = "Yu Gothic Medium"
        let ranges = SearchMatcher.highlight(haystack: text, query: "yugothic")
        // Match spans through the whitespace because we stripped it.
        XCTAssertEqual(substring(text, ranges), ["Yu Gothic"])
    }

    func testHighlightChoseongMatchMapsToOriginalSyllables() {
        let text = "산돌체 Neo"
        let ranges = SearchMatcher.highlight(haystack: text, query: "ㅅㄷ")
        XCTAssertEqual(substring(text, ranges), ["산돌"])
    }

    func testHighlightNoMatchReturnsEmpty() {
        XCTAssertTrue(SearchMatcher.highlight(haystack: "Helvetica", query: "zzz").isEmpty)
    }
}
