import Foundation
import XCTest
@testable import RootFontApp

final class FontBrowserPreferencesCodecTests: XCTestCase {
    func testRoundTrip() {
        let original = ["Mono": ["coding", "favorite"]]
        let data = FontBrowserPreferencesCodec.encode(original)

        let decoded = FontBrowserPreferencesCodec.decode(
            [String: [String]].self,
            from: data,
            default: [:]
        )

        XCTAssertEqual(decoded, original)
    }

    func testInvalidDataReturnsDefault() {
        let decoded = FontBrowserPreferencesCodec.decode(
            [String].self,
            from: Data("not-json".utf8),
            default: ["fallback"]
        )

        XCTAssertEqual(decoded, ["fallback"])
    }
}

final class FontFilterResultCacheTests: XCTestCase {
    func testEvictsOldestSignatureAtLimit() {
        let cache = FontFilterResultCache(limit: 2)
        let first = signature(query: "first")
        let second = signature(query: "second")
        let third = signature(query: "third")

        cache.store(fontIDs: ["a"], for: first)
        cache.store(fontIDs: ["b"], for: second)
        cache.store(fontIDs: ["c"], for: third)

        XCTAssertNil(cache.value(for: first))
        XCTAssertEqual(cache.value(for: second), ["b"])
        XCTAssertEqual(cache.value(for: third), ["c"])
    }

    func testClearRemovesCachedResults() {
        let cache = FontFilterResultCache(limit: 2)
        let key = signature(query: "query")
        cache.store(fontIDs: ["a"], for: key)

        cache.clear()

        XCTAssertNil(cache.value(for: key))
    }

    private func signature(query: String) -> FontFilterSignature {
        FontFilterSignature(
            searchQuery: query,
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: false,
            catalogEpoch: 0,
            favoritesSignature: 0,
            recentsSignature: 0,
            workspaceModule: .library,
            managedSignature: 0,
            scoreWeightsSignature: 0,
            manualCollectionSignature: 0,
            tagFilterSignature: 0,
            fontHealthSignature: 0
        )
    }
}
