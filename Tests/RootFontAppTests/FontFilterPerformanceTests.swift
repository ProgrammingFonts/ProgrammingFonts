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
                    normalizedNames: [$0.familyName.lowercased()],
                    choseongNames: []
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
            tagFilterFontIDs: nil
        )

        measure {
            _ = FontFilterEngine.compute(
                fonts: fonts,
                searchIndex: index,
                favoriteIDs: [],
                recentIDs: [],
                inputs: inputs
            )
        }
    }
}
