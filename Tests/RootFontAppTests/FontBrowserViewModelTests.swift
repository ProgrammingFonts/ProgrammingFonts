import XCTest
@testable import RootFontApp

@MainActor
final class FontBrowserViewModelTests: XCTestCase {
    private func waitForLoad(_ viewModel: FontBrowserViewModel, timeout: TimeInterval = 1.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.isLoading && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

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


    func testRestoresFilterStateFromStore() {
        let store = InMemoryPreferencesStore()
        store.searchQuery = "noto"
        store.sidebarFilter = FontBrowserViewModel.SidebarFilter.user.rawValue
        store.sortOption = FontBrowserViewModel.SortOption.displayName.rawValue

        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        XCTAssertEqual(viewModel.searchQuery, "noto")
        XCTAssertEqual(viewModel.sidebarFilter, .user)
        XCTAssertEqual(viewModel.sortOption, .displayName)
    }

    func testUpdateSearchSortSidebarPersistsToStore() {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.updateSearchQuery("sf")
        viewModel.updateSortOption(.displayName)
        viewModel.updateSidebarFilter(.favorites)

        XCTAssertEqual(store.searchQuery, "sf")
        XCTAssertEqual(store.sortOption, FontBrowserViewModel.SortOption.displayName.rawValue)
        XCTAssertEqual(store.sidebarFilter, FontBrowserViewModel.SidebarFilter.favorites.rawValue)
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

    func testSystemAliasFontsCollapsedByDefault() {
        let fonts = [
            FontItem(
                id: "a",
                familyName: ".AppleSystemUIFont",
                postScriptName: ".AppleSystemUIFont-Regular",
                displayName: "AppleSystemUIFont",
                source: .system,
                styleTags: [.regular]
            ),
            FontItem(
                id: "b",
                familyName: ".AppleSystemUIFont",
                postScriptName: ".AppleSystemUIFontText-Regular",
                displayName: "AppleSystemUIFont",
                source: .system,
                styleTags: [.regular]
            ),
            FontItem.sample(id: "c", familyName: "Arial", source: .system, styleTags: [.regular])
        ]
        let store = InMemoryPreferencesStore()
        store.showSystemAliasFonts = false
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: store
        )

        viewModel.load()
        waitForLoad(viewModel)

        XCTAssertEqual(viewModel.filteredFonts.count, 2)
        XCTAssertTrue(viewModel.filteredFonts.contains(where: { $0.id == "c" }))
        XCTAssertTrue(viewModel.filteredFonts.contains(where: { $0.id == "a" || $0.id == "b" }))
    }

    func testShowSystemAliasFontsTogglePersistsToStore() {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.updateShowSystemAliasFonts(true)

        XCTAssertTrue(viewModel.showSystemAliasFonts)
        XCTAssertTrue(store.showSystemAliasFonts)
    }

    func testLoadFailureSetsErrorState() {
        enum TestError: Error { case failed }
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [], error: TestError.failed),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        waitForLoad(viewModel)

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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
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

        waitForLoad(viewModel)
        viewModel.applyPreviewPreset(.numeric)

        XCTAssertEqual(viewModel.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
        XCTAssertEqual(store.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
    }
}
