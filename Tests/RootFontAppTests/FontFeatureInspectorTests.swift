import XCTest
@testable import RootFontApp

final class FontFeatureInspectorTests: XCTestCase {
    func testDetectProgrammingLigaturesFromFeatureTags() {
        let inspector = FontFeatureInspector()
        XCTAssertTrue(inspector.detectProgrammingLigatures(featureTags: ["liga"]))
        XCTAssertTrue(inspector.detectProgrammingLigatures(featureTags: ["calt"]))
        XCTAssertFalse(inspector.detectProgrammingLigatures(featureTags: ["kern", "mark"]))
    }

    func testDetectZeroVariantFromFeatureNames() {
        let inspector = FontFeatureInspector()
        XCTAssertTrue(inspector.detectZeroVariant(featureNames: ["Slashed Zero"]))
        XCTAssertTrue(inspector.detectZeroVariant(featureNames: ["Dotted zero"]))
        XCTAssertFalse(inspector.detectZeroVariant(featureNames: ["Oldstyle Figures"]))
    }

    func testCoverageBucketsFromCharacterSet() {
        let inspector = FontFeatureInspector()
        var set = CharacterSet()
        set.insert(charactersIn: "\u{0105}") // latin extended
        set.insert(charactersIn: "\u{0416}") // cyrillic
        set.insert(charactersIn: "\u{03A9}") // greek
        set.insert(charactersIn: "\u{4E2D}") // cjk

        let buckets = inspector.coverageBuckets(for: set)
        XCTAssertEqual(
            buckets,
            Set<CoverageBucket>([.latinExtended, .cyrillic, .greek, .cjk])
        )
    }
}
