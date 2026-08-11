import Foundation
import XCTest
@testable import RootFontApp

final class PreferencesStoreMigrationTests: XCTestCase {
    func testFreshStoreInitializesSchemaVersion() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.schemaVersion, PreferencesStore.currentSchemaVersion)
        XCTAssertEqual(
            defaults.integer(forKey: "rootfont.schemaVersion"),
            PreferencesStore.currentSchemaVersion
        )
    }

    func testLegacySchemaVersionMigratesForward() {
        let defaults = makeDefaults()
        defaults.set(1, forKey: "rootfont.schemaVersion")
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.schemaVersion, PreferencesStore.currentSchemaVersion)
    }

    func testResetClearsAllKeysButPreservesSchemaVersion() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.favoriteIDs = ["A", "B"]
        store.recentFontIDs = ["R"]
        store.previewText = "Hello"
        store.selectedFontID = "X"
        store.displayMode = "list"
        store.listPreviewSize = 24

        store.reset()

        XCTAssertEqual(store.favoriteIDs, [])
        XCTAssertEqual(store.recentFontIDs, [])
        XCTAssertEqual(store.previewText, "The quick brown fox jumps over the lazy dog 你好，rootfont")
        XCTAssertNil(store.selectedFontID)
        XCTAssertEqual(store.displayMode, "grid")
        XCTAssertEqual(store.listPreviewSize, 18)
        XCTAssertEqual(store.schemaVersion, PreferencesStore.currentSchemaVersion)
    }

    func testListPreviewSizeDefaultsTo18WhenUnset() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.listPreviewSize, 18)
    }

    func testListPreviewSizeRoundTrips() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.listPreviewSize = 24.5
        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.listPreviewSize, 24.5)
    }

    func testSynchronizeIsNoOp() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.synchronize()
        XCTAssertEqual(store.favoriteIDs, [])
    }

    private func makeDefaults() -> UserDefaults {
        let name = "rootfont.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
