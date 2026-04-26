import CoreGraphics
import Foundation
import XCTest
@testable import RootFontApp

final class CompareOverlaySupportTests: XCTestCase {
    func testGlyphSamplesPreferConfusablePreset() {
        let samples = CompareOverlaySupport.samples(for: .confusable, snippet: "let value = 1")
        XCTAssertFalse(samples.isEmpty)
        XCTAssertEqual(samples.first?.label, "Il1")
    }

    func testGlyphSamplesCanExtractFromSnippet() {
        let samples = CompareOverlaySupport.samples(
            for: .fromSnippet,
            snippet: "func map(_ items:[Int]) -> [Int] { items.map { $0 + 1 } }"
        )
        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testOutlineMetricsCalculateExpectedRatios() {
        let base = CGRect(x: 0, y: 0, width: 10, height: 10)
        let candidate = CGRect(x: 5, y: 0, width: 10, height: 10)
        let metrics = CompareOverlaySupport.outlineMetrics(
            baselineBounds: base,
            candidateBounds: candidate
        )
        XCTAssertEqual(metrics.overlapRatio, 0.333, accuracy: 0.01)
        XCTAssertEqual(metrics.horizontalShift, 5, accuracy: 0.01)
    }

    func testGlyphBoundsReturnsStableResultForSameInput() {
        let first = CompareOverlaySupport.glyphBounds(for: "A", postScriptName: "Menlo-Regular")
        let second = CompareOverlaySupport.glyphBounds(for: "A", postScriptName: "Menlo-Regular")
        XCTAssertEqual(first, second)
    }
}
