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
}
