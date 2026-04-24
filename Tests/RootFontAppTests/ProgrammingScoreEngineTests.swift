import XCTest
@testable import RootFontApp

final class ProgrammingScoreEngineTests: XCTestCase {
    func testReturnsNilForNonMonospacedFonts() {
        let engine = ProgrammingScoreEngine()
        let item = FontItem.sample(id: "display", familyName: "Display", source: .user, styleTags: [.regular])
        let score = engine.score(item: item, familyCoverage: FamilyWeightCoverage(buckets: [:]))
        XCTAssertNil(score)
    }

    func testHighQualityMonospaceGetsAGradeOrHigher() {
        let engine = ProgrammingScoreEngine()
        let item = FontItem(
            id: "mono",
            familyName: "Mono Family",
            postScriptName: "Mono-Regular",
            displayName: "Mono",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: true,
                availableStylisticSets: [StylisticSet(tag: "ss01", name: "Alt"), StylisticSet(tag: "ss02", name: "Alt2")],
                hasZeroVariant: true,
                hasPowerlineGlyphs: true,
                hasNerdFontGlyphs: true,
                hasBoxDrawing: true,
                coverageBuckets: [.latinExtended, .cyrillic, .greek, .cjk],
                isVariableFont: true
            ),
            metrics: FontMetricsSample(
                asciiAdvanceVariance: 0.1,
                uniformWidth: true,
                confusableDistances: [.iL1: 0.9, .o0: 0.85]
            )
        )
        let coverage = FamilyWeightCoverage(buckets: ["mono family": [.thin, .regular, .bold]])
        let score = engine.score(item: item, familyCoverage: coverage)

        XCTAssertNotNil(score)
        XCTAssertGreaterThanOrEqual(score?.total ?? 0, 70)
        XCTAssertTrue([ProgrammingGrade.s, .a].contains(score?.grade))
        XCTAssertEqual(score?.breakdown.count, ProgrammingScoreFactor.allCases.count)
    }

    func testWeakMonospaceGetsLowGrade() {
        let engine = ProgrammingScoreEngine()
        let item = FontItem(
            id: "weak",
            familyName: "Weak Mono",
            postScriptName: "Weak-Regular",
            displayName: "Weak",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: false,
                availableStylisticSets: [],
                hasZeroVariant: false,
                hasPowerlineGlyphs: false,
                hasNerdFontGlyphs: false,
                hasBoxDrawing: false,
                coverageBuckets: [],
                isVariableFont: false
            ),
            metrics: FontMetricsSample(
                asciiAdvanceVariance: 1.9,
                uniformWidth: false,
                confusableDistances: [.iL1: 0.1, .o0: 0.1]
            )
        )
        let coverage = FamilyWeightCoverage(buckets: [:])
        let score = engine.score(item: item, familyCoverage: coverage)

        XCTAssertNotNil(score)
        XCTAssertLessThan(score?.total ?? 100, 55)
        XCTAssertTrue([ProgrammingGrade.c, .notRecommended].contains(score?.grade))
    }

    func testFactorDeltasSortedByMagnitude() throws {
        let baseline = ProgrammingScore(
            total: 60,
            grade: .b,
            breakdown: [
                FactorContribution(factor: .ligatureSupport, rawValue: 0.2, weightedValue: 2, maxWeight: 10),
                FactorContribution(factor: .boxDrawing, rawValue: 0.5, weightedValue: 4, maxWeight: 8)
            ]
        )
        let candidate = ProgrammingScore(
            total: 75,
            grade: .a,
            breakdown: [
                FactorContribution(factor: .ligatureSupport, rawValue: 0.9, weightedValue: 9, maxWeight: 10),
                FactorContribution(factor: .boxDrawing, rawValue: 0.1, weightedValue: 1, maxWeight: 8)
            ]
        )

        let deltas = ProgrammingScoreEngine.factorDeltas(baseline: baseline, candidate: candidate)
        XCTAssertEqual(deltas.first?.factor, .ligatureSupport)
        let first = try XCTUnwrap(deltas.first)
        XCTAssertEqual(first.delta, 7, accuracy: 0.001)
        let box = deltas.first(where: { $0.factor == .boxDrawing })
        let boxDelta = try XCTUnwrap(box?.delta)
        XCTAssertEqual(boxDelta, -3, accuracy: 0.001)
    }

    func testGoldenCaseScoreBreakdownIsStable() throws {
        let engine = ProgrammingScoreEngine()
        let item = FontItem(
            id: "golden",
            familyName: "Golden Mono",
            postScriptName: "GoldenMono-Regular",
            displayName: "Golden Mono Regular",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: true,
                availableStylisticSets: [StylisticSet(tag: "ss01", name: "Alt")],
                hasZeroVariant: false,
                hasPowerlineGlyphs: false,
                hasNerdFontGlyphs: true,
                hasBoxDrawing: true,
                coverageBuckets: [.latinExtended, .cyrillic],
                isVariableFont: false
            ),
            metrics: FontMetricsSample(
                asciiAdvanceVariance: 0.2,
                uniformWidth: true,
                confusableDistances: [.iL1: 0.5, .o0: 0.7]
            )
        )
        let coverage = FamilyWeightCoverage(
            buckets: ["golden mono": Set<WeightTier>([.regular, .bold, .black])]
        )

        let score = try XCTUnwrap(engine.score(item: item, familyCoverage: coverage))
        XCTAssertEqual(score.total, 75)
        XCTAssertEqual(score.grade, .a)

        let breakdownByFactor = Dictionary(uniqueKeysWithValues: score.breakdown.map { ($0.factor, $0.weightedValue) })
        XCTAssertEqual(try XCTUnwrap(breakdownByFactor[.monospaceBaseline]), 30, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(breakdownByFactor[.glyphDisambiguation]), 12, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(breakdownByFactor[.stylisticFlexibility]), 8.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(breakdownByFactor[.languageCoverage]), 2.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(breakdownByFactor[.weightVariety]), 5, accuracy: 0.001)
    }
}
