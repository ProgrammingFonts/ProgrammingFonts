import XCTest
@testable import RootFontApp

#if DEBUG
final class CacheDiagnosticsTests: XCTestCase {
    override func setUp() {
        CacheDiagnostics.shared.reset()
    }

    func testCoverageCacheRecordsHitsMissesAndEvictions() {
        var cache = CoverageCache(limit: 1)
        XCTAssertNil(cache.value(for: "a"))
        cache.store(true, for: "a")
        XCTAssertEqual(cache.value(for: "a"), true)
        cache.store(false, for: "b")

        XCTAssertEqual(
            CacheDiagnostics.shared.snapshot(for: "coverage"),
            .init(hits: 1, misses: 1, evictions: 1)
        )
    }
}
#endif
