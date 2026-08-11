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

    func testSaveMethodsOwnPreferenceWrites() {
        let store = InMemoryPreferencesStore()
        let controller = FontBrowserPreferencesController(store: store)

        controller.saveFavorites(["favorite"])
        controller.saveRecents(["recent"])
        controller.saveLanguage(.japanese)
        controller.saveAppearance(.dark)
        controller.saveSearchQuery("mono")
        controller.saveSidebarFilter(.favorites)
        controller.saveSortOption(.displayName)
        controller.saveSelectedFontID("selected")
        controller.watchFontFoldersEnabled = false

        XCTAssertEqual(store.favoriteIDs, ["favorite"])
        XCTAssertEqual(store.recentFontIDs, ["recent"])
        XCTAssertEqual(store.appLanguage, .japanese)
        XCTAssertTrue(store.didChooseAppLanguage)
        XCTAssertEqual(store.appearanceMode, .dark)
        XCTAssertEqual(store.searchQuery, "mono")
        XCTAssertEqual(store.sidebarFilter, SidebarFilter.favorites.rawValue)
        XCTAssertEqual(store.sortOption, SortOption.displayName.rawValue)
        XCTAssertEqual(store.selectedFontID, "selected")
        XCTAssertFalse(store.watchFontFoldersEnabled)
    }
}
