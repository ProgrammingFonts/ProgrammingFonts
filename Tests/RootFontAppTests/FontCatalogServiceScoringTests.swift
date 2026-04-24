import XCTest
@testable import RootFontApp

final class FontCatalogServiceScoringTests: XCTestCase {
    func testAttachProgrammingScoresSetsScoreForMonospacedOnly() {
        let mono = FontItem(
            id: "mono",
            familyName: "Mono Family",
            postScriptName: "Mono-Regular",
            displayName: "Mono",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: true,
                availableStylisticSets: [],
                hasZeroVariant: true,
                hasPowerlineGlyphs: false,
                hasNerdFontGlyphs: false,
                hasBoxDrawing: true,
                coverageBuckets: [.latinExtended, .cyrillic],
                isVariableFont: false
            ),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.1, uniformWidth: true, confusableDistances: [.iL1: 0.8])
        )
        let display = FontItem(
            id: "display",
            familyName: "Display Family",
            postScriptName: "Display-Regular",
            displayName: "Display",
            source: .user,
            styleTags: [.regular],
            programming: ProgrammingProfile.empty.withMonospaced(false),
            metrics: nil
        )

        let scored = FontCatalogService.attachProgrammingScores([mono, display])
        let monoScore = scored.first(where: { $0.id == "mono" })?.programmingScore
        let displayScore = scored.first(where: { $0.id == "display" })?.programmingScore

        XCTAssertNotNil(monoScore)
        XCTAssertNil(displayScore)
    }

    func testAttachProgrammingScoresUsesFamilyWeightCoverage() {
        let regular = FontItem(
            id: "regular",
            familyName: "Mono Family",
            postScriptName: "Mono-Regular",
            displayName: "Mono Regular",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.2, uniformWidth: true, confusableDistances: [:])
        )
        let bold = FontItem(
            id: "bold",
            familyName: "Mono Family",
            postScriptName: "Mono-Bold",
            displayName: "Mono Bold",
            source: .user,
            styleTags: [.bold, .monospace],
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.2, uniformWidth: true, confusableDistances: [:])
        )
        let black = FontItem(
            id: "black",
            familyName: "Mono Family",
            postScriptName: "Mono-Black",
            displayName: "Mono Black",
            source: .user,
            styleTags: [.bold, .monospace],
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.2, uniformWidth: true, confusableDistances: [:])
        )

        let coverage = FamilyWeightCoverage(buckets: ["mono family": [.thin, .regular, .bold]])
        let scored = FontCatalogService.attachProgrammingScores(
            [regular, bold, black],
            familyCoverage: coverage
        )
        let contribution = scored.first(where: { $0.id == "regular" })?
            .programmingScore?
            .breakdown
            .first(where: { $0.factor == .weightVariety })

        XCTAssertNotNil(contribution)
        guard let contribution else { return }
        XCTAssertEqual(contribution.weightedValue, contribution.maxWeight, accuracy: 0.001)
    }
}

private extension ProgrammingProfile {
    func withMonospaced(_ value: Bool) -> ProgrammingProfile {
        var copy = self
        copy.isMonospaced = value
        return copy
    }
}
