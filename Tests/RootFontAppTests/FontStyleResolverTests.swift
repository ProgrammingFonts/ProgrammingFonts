import AppKit
import XCTest
@testable import RootFontApp

final class FontStyleResolverTests: XCTestCase {
    func testMonospacedSystemFontGetsMonospaceTag() {
        let resolver = FontStyleResolver()
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let tags = resolver.resolveStyleTags(for: font)
        XCTAssertTrue(tags.contains(.monospace))
    }

    func testRegularSystemFontDoesNotAlwaysHaveMonospaceTag() {
        let resolver = FontStyleResolver()
        let font = NSFont.systemFont(ofSize: 13)

        let tags = resolver.resolveStyleTags(for: font)
        XCTAssertFalse(tags.contains(.monospace))
    }
}
