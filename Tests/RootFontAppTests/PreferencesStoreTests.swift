import Foundation
import XCTest
@testable import RootFontApp

final class PreferencesStoreTests: XCTestCase {
    func testDefaultsFallBackWhenUnset() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.previewText, "The quick brown fox jumps over the lazy dog 你好，rootfont")
        XCTAssertEqual(store.previewSize, 32)
        XCTAssertEqual(store.appLanguage, .english)
        XCTAssertEqual(store.appearanceMode, .system)
        XCTAssertFalse(store.showSystemAliasFonts)
        XCTAssertEqual(store.searchQuery, "")
        XCTAssertEqual(store.sidebarFilter, "all")
        XCTAssertEqual(store.sortOption, "familyName")
    }

    func testRoundTripsPersistedValues() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)

        store.favoriteIDs = ["A", "B"]
        store.recentFontIDs = ["Recent"]
        store.previewText = "Hello"
        store.previewSize = 18
        store.didChooseAppLanguage = true
        store.appLanguage = .french
        store.appearanceMode = .dark
        store.showSystemAliasFonts = true
        store.searchQuery = "mono"
        store.sidebarFilter = "favorites"
        store.sortOption = "displayName"
        store.selectedFontID = "SFMono-Regular"

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.favoriteIDs, ["A", "B"])
        XCTAssertEqual(reloaded.recentFontIDs, ["Recent"])
        XCTAssertEqual(reloaded.previewText, "Hello")
        XCTAssertEqual(reloaded.previewSize, 18)
        XCTAssertEqual(reloaded.appLanguage, .french)
        XCTAssertEqual(reloaded.appearanceMode, .dark)
        XCTAssertTrue(reloaded.showSystemAliasFonts)
        XCTAssertEqual(reloaded.searchQuery, "mono")
        XCTAssertEqual(reloaded.sidebarFilter, "favorites")
        XCTAssertEqual(reloaded.sortOption, "displayName")
        XCTAssertEqual(reloaded.selectedFontID, "SFMono-Regular")
    }

    private func makeDefaults() -> UserDefaults {
        let name = "rootfont.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
