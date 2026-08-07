import Foundation
import XCTest
@testable import RootFontApp

final class FontBrowserPreferencesControllerTests: XCTestCase {
    func testRestoreFallsBackForInvalidEnumsAndCorruptedData() {
        let store = InMemoryPreferencesStore()
        store.sidebarFilter = "removed-filter"
        store.sortOption = "removed-sort"
        store.smartCollectionsData = Data("not-json".utf8)
        store.manualCollectionsData = Data([0x01, 0x02])
        store.fontTagsData = Data("[]".utf8)
        store.scoreWeightsData = Data("invalid".utf8)
        store.fontFeaturePrefsData = Data("null".utf8)
        store.customSnippetsData = Data("broken".utf8)

        let state = FontBrowserPreferencesController(store: store).restore()

        XCTAssertEqual(state.sidebarFilter, .all)
        XCTAssertEqual(state.sortOption, .familyName)
        XCTAssertTrue(state.smartCollections.isEmpty)
        XCTAssertTrue(state.manualCollections.isEmpty)
        XCTAssertTrue(state.fontTagAssignments.isEmpty)
        XCTAssertNil(state.scoreWeights)
        XCTAssertTrue(state.featurePreferences.isEmpty)
        XCTAssertTrue(state.customSnippets.isEmpty)
    }

    func testRestoreKeepsLegacyCorePreferences() {
        let store = InMemoryPreferencesStore()
        store.favoriteIDs = ["favorite"]
        store.recentFontIDs = ["recent"]
        store.searchQuery = "mono"
        store.sidebarFilter = SidebarFilter.favorites.rawValue
        store.sortOption = SortOption.displayName.rawValue
        store.selectedFontID = "selected"

        let state = FontBrowserPreferencesController(store: store).restore()

        XCTAssertEqual(state.favoriteIDs, ["favorite"])
        XCTAssertEqual(state.recentFontIDs, ["recent"])
        XCTAssertEqual(state.searchQuery, "mono")
        XCTAssertEqual(state.sidebarFilter, .favorites)
        XCTAssertEqual(state.sortOption, .displayName)
        XCTAssertEqual(state.selectedFontID, "selected")
    }
}
