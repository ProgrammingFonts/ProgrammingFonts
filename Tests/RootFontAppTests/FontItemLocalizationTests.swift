import XCTest
@testable import RootFontApp

final class FontItemLocalizationTests: XCTestCase {
    private func makeItem() -> FontItem {
        FontItem(
            id: "Hiragino-W3",
            familyName: "Hiragino Sans",
            postScriptName: "HiraginoSans-W3",
            displayName: "Hiragino Sans W3",
            source: .system,
            styleTags: [.regular],
            localizedFamilyNames: ["ja": "ヒラギノ角ゴシック"],
            localizedDisplayNames: ["ja": "ヒラギノ角ゴシック W3"]
        )
    }

    func testFamilyNameUsesLocalizedVariantWhenAvailable() {
        let item = makeItem()
        XCTAssertEqual(item.familyName(for: .japanese), "ヒラギノ角ゴシック")
        XCTAssertEqual(item.familyName(for: .english), "Hiragino Sans")
        XCTAssertEqual(item.familyName(for: .korean), "Hiragino Sans")
    }

    func testDisplayNameFallsBackToCanonical() {
        let item = makeItem()
        XCTAssertEqual(item.displayName(for: .japanese), "ヒラギノ角ゴシック W3")
        XCTAssertEqual(item.displayName(for: .simplifiedChinese), "Hiragino Sans W3")
    }

    func testSearchableNamesIncludeAllUniqueVariants() {
        let item = makeItem()
        let names = item.searchableNames
        XCTAssertTrue(names.contains("Hiragino Sans"))
        XCTAssertTrue(names.contains("HiraginoSans-W3"))
        XCTAssertTrue(names.contains("ヒラギノ角ゴシック"))
        XCTAssertTrue(names.contains("ヒラギノ角ゴシック W3"))
        XCTAssertEqual(Set(names).count, names.count, "Searchable names should be unique")
    }

    func testSearchableNamesDropEmptyAndDuplicate() {
        let item = FontItem(
            id: "a",
            familyName: "Arial",
            postScriptName: "Arial",
            displayName: "Arial",
            source: .system,
            styleTags: [.regular],
            localizedFamilyNames: ["ja": "Arial"]
        )
        XCTAssertEqual(item.searchableNames, ["Arial"])
    }

    func testLocalizedFontMatchesLocalizedSearch() {
        let item = makeItem()
        let matched = item.searchableNames.contains { name in
            SearchMatcher.matches(haystack: name, query: "ひらぎの")
        }
        XCTAssertTrue(matched, "Query in hiragana should match katakana localized name")
    }

    func testFontStyleIncludesMonospaceTag() {
        XCTAssertTrue(FontStyleTag.allCases.contains(.monospace))
    }

    func testProgrammingFieldsDefaultToNil() {
        let item = FontItem.sample(
            id: "sample",
            familyName: "Sample Mono",
            source: .user,
            styleTags: [.regular]
        )

        XCTAssertNil(item.programming)
        XCTAssertNil(item.metrics)
        XCTAssertNil(item.programmingScore)
    }

    func testDecodingLegacyPayloadKeepsNewFieldsNil() throws {
        let json = """
        {
          "id": "legacy",
          "familyName": "Legacy",
          "postScriptName": "Legacy-Regular",
          "displayName": "Legacy Regular",
          "source": "system",
          "styleTags": ["regular"],
          "localizedFamilyNames": {},
          "localizedDisplayNames": {}
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(FontItem.self, from: json)
        XCTAssertNil(item.programming)
        XCTAssertNil(item.metrics)
        XCTAssertNil(item.programmingScore)
    }
}
