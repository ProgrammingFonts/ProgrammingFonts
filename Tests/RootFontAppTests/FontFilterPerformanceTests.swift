import XCTest
@testable import RootFontApp

final class FontFilterPerformanceTests: XCTestCase {
    func testFilterPerformanceOnLargeCatalog() {
        let fonts = (0..<2000).map { index in
            FontItem.sample(
                id: "Font-\(index)",
                familyName: "Family \(index)",
                source: index.isMultiple(of: 2) ? .system : .user,
                styleTags: index.isMultiple(of: 3) ? [.monospace] : [.regular]
            )
        }
        let index = Dictionary(
            uniqueKeysWithValues: fonts.map {
                ($0.id, FontFilterEngine.SearchIndexEntry(
                    normalizedNames: [SearchMatcher.normalize($0.familyName)],
                    choseongNames: [SearchMatcher.choseongProjection($0.familyName)]
                ))
            }
        )
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: "family 17"),
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            scoreWeights: .default,
            managedFontIDs: [],
            manualCollectionFontIDs: nil,
            tagFilterFontIDs: nil,
            fontHealthFontIDs: nil,
            familyWeightCoverage: nil,
            coverageSupportCache: [:]
        )

        measure {
        _ = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: index,
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        ).fonts
        }
    }

    func testFilterLargeCatalogCompletesWithinBudget() {
        let fonts = (0..<2000).map { index in
            FontItem.sample(
                id: "Font-\(index)",
                familyName: "Family \(index)",
                source: index.isMultiple(of: 2) ? .system : .user,
                styleTags: index.isMultiple(of: 3) ? [.monospace] : [.regular]
            )
        }
        let index = Dictionary(
            uniqueKeysWithValues: fonts.map {
                ($0.id, FontFilterEngine.SearchIndexEntry(
                    normalizedNames: [SearchMatcher.normalize($0.familyName)],
                    choseongNames: [SearchMatcher.choseongProjection($0.familyName)]
                ))
            }
        )
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: "family 17"),
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            scoreWeights: .default,
            managedFontIDs: [],
            manualCollectionFontIDs: nil,
            tagFilterFontIDs: nil,
            fontHealthFontIDs: nil,
            familyWeightCoverage: nil,
            coverageSupportCache: [:]
        )

        let start = CFAbsoluteTimeGetCurrent()
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: index,
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        ).fonts
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThan(elapsed, 1.0, "Filtering 2000 fonts should complete within 1s (took \(elapsed)s)")
    }
}
