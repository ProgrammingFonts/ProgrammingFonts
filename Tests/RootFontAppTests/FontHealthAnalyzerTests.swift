import XCTest
@testable import RootFontApp

final class FontHealthAnalyzerTests: XCTestCase {
    func testDetectsDuplicateStylesInSameFamily() {
        let regular = FontItem.sample(
            id: "a-regular",
            familyName: "Duplex",
            source: .user,
            styleTags: [.regular]
        )
        let regularCopy = FontItem(
            id: "b-regular",
            familyName: "Duplex",
            postScriptName: "Duplex-Regular-Alt",
            displayName: "Duplex Regular Alt",
            source: .user,
            styleTags: [.regular]
        )

        let report = FontHealthAnalyzer.analyze(fonts: [regular, regularCopy])

        XCTAssertEqual(report.duplicateFontIDs, Set(["a-regular", "b-regular"]))
        XCTAssertEqual(report.duplicateGroupCount, 1)
        XCTAssertEqual(report.duplicateGroups.count, 1)
        XCTAssertEqual(report.duplicateGroups.first?.fontIDs.count, 2)
        XCTAssertTrue(report.affectedFontIDs.contains("a-regular"))
    }

    func testBrokenFontUsesMissingPostScriptName() {
        let broken = FontItem(
            id: "broken",
            familyName: "Missing",
            postScriptName: "Definitely-Not-A-Real-Font-12345",
            displayName: "Missing",
            source: .user,
            styleTags: [.regular]
        )

        let report = FontHealthAnalyzer.analyze(fonts: [broken])

        XCTAssertTrue(report.brokenFontIDs.contains("broken"))
    }

    func testDifferentWeightsInSameFamilyAreNotDuplicates() {
        var regular = FontItem.sample(
            id: "duplex-regular",
            familyName: "Duplex",
            source: .user,
            styleTags: [.regular]
        )
        regular.weightTier = .regular
        var light = FontItem.sample(
            id: "duplex-light",
            familyName: "Duplex",
            source: .user,
            styleTags: [.regular]
        )
        light.weightTier = .thin

        let report = FontHealthAnalyzer.analyze(fonts: [regular, light])

        XCTAssertTrue(report.duplicateFontIDs.isEmpty)
        XCTAssertEqual(report.duplicateGroupCount, 0)
    }

    func testTextReportIncludesSections() {
        let broken = FontItem(
            id: "broken",
            familyName: "Missing",
            postScriptName: "Definitely-Not-A-Real-Font-12345",
            displayName: "Missing",
            source: .user,
            styleTags: [.regular]
        )
        let report = FontHealthAnalyzer.analyze(fonts: [broken])
        let text = FontHealthReportExporter.textReport(
            report: report,
            fontsByID: ["broken": broken],
            context: FontHealthReportContext(
                generatedAt: Date(timeIntervalSince1970: 0),
                brokenLabel: "Broken fonts",
                duplicateLabel: "Duplicate styles",
                duplicateGroupLabel: "Duplicate groups",
                sourceSystemLabel: "System",
                sourceUserLabel: "User",
                styleLabel: { _ in "Regular" },
                familyName: { $0.familyName },
                displayName: { $0.displayName }
            )
        )
        XCTAssertTrue(text.contains("rootfont Font Health Report"))
        XCTAssertTrue(text.contains("Broken fonts"))
        XCTAssertTrue(text.contains("Missing"))
    }
}

final class FontFilterEngineFontHealthTests: XCTestCase {
    func testFontHealthSidebarFilterLimitsToAffectedFonts() {
        let healthy = FontItem.sample(
            id: "healthy",
            familyName: "Healthy",
            source: .system,
            styleTags: [.regular]
        )
        let broken = FontItem(
            id: "broken",
            familyName: "Broken",
            postScriptName: "Definitely-Not-A-Real-Font-12345",
            displayName: "Broken",
            source: .user,
            styleTags: [.regular]
        )
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .fontHealth,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            scoreWeights: .default,
            managedFontIDs: [],
            manualCollectionFontIDs: nil,
            tagFilterFontIDs: nil,
            fontHealthFontIDs: ["broken"],
            familyWeightCoverage: nil,
            coverageSupportCache: [:]
        )

        let output = FontFilterEngine.compute(
            fonts: [healthy, broken],
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        )

        XCTAssertEqual(output.fonts.map(\.id), ["broken"])
    }
}
