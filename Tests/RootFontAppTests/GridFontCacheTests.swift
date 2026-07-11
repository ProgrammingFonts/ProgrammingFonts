import AppKit
import XCTest
@testable import RootFontApp

final class GridFontCacheTests: XCTestCase {
    func testCachesResolvedFontForRepeatedLookup() {
        let base = NSFont.systemFont(ofSize: 18)
        let cache = GridFontCache(limit: 8)
        var resolveCount = 0
        let provider: (String, CGFloat) -> NSFont? = { _, _ in
            resolveCount += 1
            return base
        }

        _ = cache.font(postScriptName: "Test-Regular", size: 18, provider: provider)
        _ = cache.font(postScriptName: "Test-Regular", size: 18, provider: provider)

        XCTAssertEqual(resolveCount, 1)
    }

    func testDifferentSizesProduceSeparateCacheEntries() {
        let base = NSFont.systemFont(ofSize: 14)
        let cache = GridFontCache(limit: 8)
        var resolveCount = 0
        let provider: (String, CGFloat) -> NSFont? = { _, _ in
            resolveCount += 1
            return base
        }

        _ = cache.font(postScriptName: "Test-Regular", size: 14, provider: provider)
        _ = cache.font(postScriptName: "Test-Regular", size: 16, provider: provider)

        XCTAssertEqual(resolveCount, 2)
    }
}

final class NSFontResolveCacheTests: XCTestCase {
    func testCachesResolvedFontForRepeatedLookup() {
        let base = NSFont.systemFont(ofSize: 16)
        let cache = NSFontResolveCache(limit: 8)
        var resolveCount = 0
        let provider: (String, CGFloat) -> NSFont? = { _, _ in
            resolveCount += 1
            return base
        }

        _ = cache.font(postScriptName: "Mono-Regular", size: 16, provider: provider)
        _ = cache.font(postScriptName: "Mono-Regular", size: 16, provider: provider)

        XCTAssertEqual(resolveCount, 1)
    }
}
