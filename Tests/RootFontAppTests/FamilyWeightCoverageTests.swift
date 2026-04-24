import XCTest
@testable import RootFontApp

final class FamilyWeightCoverageTests: XCTestCase {
    func testBuildBucketsWeightsPerFamily() {
        let fonts = [
            FontItem(
                id: "a-regular",
                familyName: "Alpha Mono",
                postScriptName: "Alpha-Mono-Regular",
                displayName: "Alpha Mono Regular",
                source: .user,
                styleTags: [.regular, .monospace]
            ),
            FontItem(
                id: "a-bold",
                familyName: "Alpha Mono",
                postScriptName: "Alpha-Mono-Bold",
                displayName: "Alpha Mono Bold",
                source: .user,
                styleTags: [.bold, .monospace]
            ),
            FontItem(
                id: "b-black",
                familyName: "Beta Mono",
                postScriptName: "Beta-Mono-Black",
                displayName: "Beta Mono Black",
                source: .user,
                styleTags: [.regular, .monospace]
            )
        ]

        let resolver = MockWeightTierResolver(map: [
            "Alpha-Mono-Regular": .regular,
            "Alpha-Mono-Bold": .bold,
            "Beta-Mono-Black": .black
        ])

        let coverage = FamilyWeightCoverage.build(from: fonts, resolver: resolver)
        XCTAssertEqual(coverage.tiers(forFamilyName: "Alpha Mono"), Set([.regular, .bold]))
        XCTAssertEqual(coverage.tiers(forFamilyName: "Beta Mono"), Set([.black]))
    }

    func testHasWeightVarietyRequiresAtLeastThreeTiers() {
        let coverage = FamilyWeightCoverage(buckets: [
            "alpha mono": Set([.regular, .bold]),
            "beta mono": Set([.thin, .regular, .bold])
        ])

        XCTAssertFalse(coverage.hasWeightVariety(familyName: "Alpha Mono"))
        XCTAssertTrue(coverage.hasWeightVariety(familyName: "Beta Mono"))
    }
}

private struct MockWeightTierResolver: FontWeightTierResolving {
    let map: [String: WeightTier]

    func resolveWeightTier(postScriptName: String) -> WeightTier {
        map[postScriptName] ?? .regular
    }
}
