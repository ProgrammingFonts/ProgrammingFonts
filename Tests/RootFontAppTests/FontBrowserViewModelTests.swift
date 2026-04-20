import XCTest
@testable import RootFontApp

@MainActor
final class FontBrowserViewModelTests: XCTestCase {
    func testLanguageDefaultsToEnglishWhenNotChosen() {
        let store = InMemoryPreferencesStore()
        store.appLanguage = .traditionalChinese
        store.didChooseAppLanguage = false

        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        XCTAssertEqual(viewModel.language, .english)
        XCTAssertEqual(viewModel.tr(.settings), "Settings")
    }

    func testUpdateLanguagePersistsToStore() {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.updateLanguage(.traditionalChinese)

        XCTAssertEqual(viewModel.language, .traditionalChinese)
        XCTAssertEqual(store.appLanguage, .traditionalChinese)
        XCTAssertTrue(store.didChooseAppLanguage)
        XCTAssertEqual(viewModel.tr(.settings), "設定")
    }

    func testUpdateAppearanceModePersistsToStore() {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.updateAppearanceMode(.dark)

        XCTAssertEqual(viewModel.appearanceMode, .dark)
        XCTAssertEqual(store.appearanceMode, .dark)
    }

    func testLoadFailureSetsErrorState() {
        enum TestError: Error { case failed }
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [], error: TestError.failed),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()

        XCTAssertNotNil(viewModel.loadErrorMessage)
        XCTAssertTrue(viewModel.filteredFonts.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testFiltersBySearchKeyword() {
        let fonts = [
            FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular]),
            FontItem.sample(id: "2", familyName: "PingFang SC", source: .system, styleTags: [.regular])
        ]
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.searchQuery = "ping"
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.familyName), ["PingFang SC"])
    }

    func testFiltersBySourceAndStyle() {
        let fonts = [
            FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.bold]),
            FontItem.sample(id: "2", familyName: "CustomSans", source: .user, styleTags: [.bold]),
            FontItem.sample(id: "3", familyName: "CustomSans", source: .user, styleTags: [.italic])
        ]
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.selectedSource = .user
        viewModel.selectedStyle = .bold
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.count, 1)
        XCTAssertEqual(viewModel.filteredFonts.first?.id, "2")
    }

    func testFavoriteTogglePersistsState() {
        let item = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [item]),
            preferencesStore: store
        )

        viewModel.load()
        viewModel.toggleFavorite(item)

        XCTAssertTrue(viewModel.favoriteIDs.contains(item.id))
        XCTAssertTrue(store.favoriteIDs.contains(item.id))
    }

    func testSelectingFontAddsToRecentsWithoutDuplicates() {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let second = FontItem.sample(id: "2", familyName: "Avenir", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first, second]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.selectFont(first)
        viewModel.selectFont(second)
        viewModel.selectFont(first)

        XCTAssertEqual(viewModel.recentFontIDs, ["1", "2"])
    }

    func testRecentsFilterUsesRecencyOrder() {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let second = FontItem.sample(id: "2", familyName: "Avenir", source: .system, styleTags: [.regular])
        let third = FontItem.sample(id: "3", familyName: "Helvetica", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first, second, third]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.selectFont(second)
        viewModel.selectFont(first)
        viewModel.selectFont(third)
        viewModel.sidebarFilter = .recents
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["3", "1", "2"])
    }

    func testSortByDisplayName() {
        let zebra = FontItem(
            id: "1",
            familyName: "Family B",
            postScriptName: "FamilyB",
            displayName: "Zebra",
            source: .system,
            styleTags: [.regular]
        )
        let alpha = FontItem(
            id: "2",
            familyName: "Family A",
            postScriptName: "FamilyA",
            displayName: "Alpha",
            source: .system,
            styleTags: [.regular]
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [zebra, alpha]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.sortOption = .displayName
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.displayName), ["Alpha", "Zebra"])
    }

    func testClearAllFiltersResetsState() {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        viewModel.searchQuery = "a"
        viewModel.selectedSource = .user
        viewModel.selectedStyle = .bold
        viewModel.sidebarFilter = .favorites
        viewModel.sortOption = .displayName
        viewModel.clearAllFilters()

        XCTAssertEqual(viewModel.searchQuery, "")
        XCTAssertNil(viewModel.selectedSource)
        XCTAssertNil(viewModel.selectedStyle)
        XCTAssertEqual(viewModel.sidebarFilter, .all)
        XCTAssertEqual(viewModel.sortOption, .familyName)
    }

    func testApplyPreviewPresetUpdatesPreviewText() {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first]),
            preferencesStore: store
        )

        viewModel.load()
        viewModel.applyPreviewPreset(.numeric)

        XCTAssertEqual(viewModel.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
        XCTAssertEqual(store.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
    }
}
