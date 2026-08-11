import Foundation
import XCTest
@testable import RootFontApp

final class FontBrowserPreferencesCodecTests: XCTestCase {
    func testRoundTrip() {
        let original = ["Mono": ["coding", "favorite"]]
        let data = FontBrowserPreferencesCodec.encode(original)
        XCTAssertEqual(
            FontBrowserPreferencesCodec.decode([String: [String]].self, from: data, default: [:]),
            original
        )
    }

    func testInvalidDataReturnsDefault() {
        XCTAssertEqual(
            FontBrowserPreferencesCodec.decode(
                [String].self,
                from: Data("not-json".utf8),
                default: ["fallback"]
            ),
            ["fallback"]
        )
    }
}
