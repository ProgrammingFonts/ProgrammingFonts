import XCTest
@testable import RootFontApp

final class FontMetricsProbeTests: XCTestCase {
    func testMeasureReturnsNilForNonMonospacedCandidate() {
        let probe = FontMetricsProbe()
        let sample = probe.measure(postScriptName: "Menlo-Regular", isMonospaced: false)
        XCTAssertNil(sample)
    }

    func testAsciiAdvanceVarianceIsZeroForUniformValues() {
        let probe = FontMetricsProbe()
        XCTAssertEqual(probe.asciiAdvanceVariance(for: [7, 7, 7, 7]), 0, accuracy: 0.0001)
    }

    func testAsciiAdvanceVarianceReflectsSpread() {
        let probe = FontMetricsProbe()
        XCTAssertEqual(probe.asciiAdvanceVariance(for: [5, 6.5, 7]), 2, accuracy: 0.0001)
    }
}
