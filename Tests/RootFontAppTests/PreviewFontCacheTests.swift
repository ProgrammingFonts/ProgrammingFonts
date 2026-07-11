import AppKit
import XCTest
@testable import RootFontApp

final class PreviewFontCacheTests: XCTestCase {
    func testCachesBoundFontForRepeatedLookup() {
        let base = NSFont.systemFont(ofSize: 14)
        let binder = CountingFeatureBinder(returnFont: base)
        let cache = PreviewFontCache(limit: 8)
        let options = OpenTypeFeatureOptions(
            ligaturesEnabled: true,
            zeroVariantEnabled: false,
            stylisticSetTags: ["ss01"]
        )
        let provider: (String, CGFloat) -> NSFont? = { _, _ in base }

        _ = cache.nsFont(
            postScriptName: "Test-Regular",
            size: 14,
            options: options,
            binder: binder,
            baseFontProvider: provider
        )
        _ = cache.nsFont(
            postScriptName: "Test-Regular",
            size: 14,
            options: options,
            binder: binder,
            baseFontProvider: provider
        )

        XCTAssertEqual(binder.bindCount, 1)
    }

    func testDifferentFeatureOptionsProduceSeparateCacheEntries() {
        let base = NSFont.systemFont(ofSize: 16)
        let binder = CountingFeatureBinder(returnFont: base)
        let cache = PreviewFontCache(limit: 8)
        let provider: (String, CGFloat) -> NSFont? = { _, _ in base }

        _ = cache.nsFont(
            postScriptName: "Test-Regular",
            size: 16,
            options: OpenTypeFeatureOptions(ligaturesEnabled: true, zeroVariantEnabled: false, stylisticSetTags: []),
            binder: binder,
            baseFontProvider: provider
        )
        _ = cache.nsFont(
            postScriptName: "Test-Regular",
            size: 16,
            options: OpenTypeFeatureOptions(ligaturesEnabled: false, zeroVariantEnabled: false, stylisticSetTags: []),
            binder: binder,
            baseFontProvider: provider
        )

        XCTAssertEqual(binder.bindCount, 2)
    }
}

private final class CountingFeatureBinder: OpenTypeFeatureBinding, @unchecked Sendable {
    let returnFont: NSFont
    private(set) var bindCount = 0

    init(returnFont: NSFont) {
        self.returnFont = returnFont
    }

    func bind(base: NSFont, options: OpenTypeFeatureOptions) -> NSFont {
        bindCount += 1
        return returnFont
    }
}
