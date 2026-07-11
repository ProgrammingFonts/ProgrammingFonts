import XCTest
@testable import RootFontApp

final class FontFilterEngineTests: XCTestCase {
    func testFiltersBySourceAndFavorites() {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .system, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.monospace]),
        ]
        let index: [String: FontFilterEngine.SearchIndexEntry] = [
            "A": .init(normalizedNames: ["alpha"], choseongNames: []),
            "B": .init(normalizedNames: ["beta"], choseongNames: []),
        ]
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
            coverageQuery: "",
            selectedSource: .user,
            selectedStyle: nil,
            sidebarFilter: .favorites,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            scoreWeights: .default,
            managedFontIDs: [],
            manualCollectionFontIDs: nil,
            tagFilterFontIDs: nil
        )
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: index,
            favoriteIDs: ["B"],
            recentIDs: [],
            inputs: inputs
        )
        XCTAssertEqual(result.fonts.map(\.id), ["B"])
    }

    func testSortsByFamilyName() {
        let fonts = [
            FontItem.sample(id: "Z", familyName: "Zebra", source: .system, styleTags: [.regular]),
            FontItem.sample(id: "A", familyName: "Alpha", source: .system, styleTags: [.regular]),
        ]
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
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
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        )
        XCTAssertEqual(result.fonts.map(\.familyName), ["Alpha", "Zebra"])
    }

    func testAllSidebarSkipsFamilyCoverageBuild() {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .system, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.monospace]),
        ]
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
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
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        )
        XCTAssertEqual(result.fonts.map(\.id).sorted(), ["A", "B"])
    }

    func testFiltersByManualCollectionMembership() {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.regular]),
        ]
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            scoreWeights: .default,
            managedFontIDs: [],
            manualCollectionFontIDs: ["A"],
            tagFilterFontIDs: nil
        )
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        )
        XCTAssertEqual(result.fonts.map(\.id), ["A"])
    }

    func testFiltersByTagMembership() {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.regular]),
        ]
        let inputs = FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: ""),
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
            tagFilterFontIDs: ["B"]
        )
        let result = FontFilterEngine.compute(
            fonts: fonts,
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: inputs
        )
        XCTAssertEqual(result.fonts.map(\.id), ["B"])
    }
}
