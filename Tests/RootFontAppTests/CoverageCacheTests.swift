import XCTest
@testable import RootFontApp

final class CoverageCacheTests: XCTestCase {
    func testHitTouchesKeySoItSurvivesTrim() {
        var cache = CoverageCache(limit: 2)
        cache.store(true, for: "a")
        cache.store(false, for: "b")
        XCTAssertEqual(cache.value(for: "a"), true) // touch a
        cache.store(true, for: "c") // should evict b, keep a
        XCTAssertEqual(cache.value(for: "a"), true)
        XCTAssertNil(cache.values["b"])
        XCTAssertEqual(cache.values["c"], true)
    }

    func testMergeUpdatesAndTrims() {
        var cache = CoverageCache(limit: 2)
        cache.store(true, for: "x")
        cache.store(false, for: "y")
        cache.merge(["z": true])
        XCTAssertEqual(cache.values.count, 2)
        XCTAssertNil(cache.values["x"])
        XCTAssertEqual(cache.values["y"], false)
        XCTAssertEqual(cache.values["z"], true)
    }
}
