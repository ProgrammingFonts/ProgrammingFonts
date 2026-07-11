import XCTest
@testable import RootFontApp

@MainActor
final class FontBrowserViewModelTests: XCTestCase {
    private func waitForLoad(_ viewModel: FontBrowserViewModel, timeout: TimeInterval = 2.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.isLoading && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        if viewModel.isLoading {
            XCTFail("Timed out waiting for font catalog load")
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

    func testJapaneseAndKoreanLocalizationCanBeSelected() {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.updateLanguage(.japanese)
        XCTAssertEqual(viewModel.tr(.settings), "設定")
        XCTAssertEqual(store.appLanguage, .japanese)

        viewModel.updateLanguage(.korean)
        XCTAssertEqual(viewModel.tr(.settings), "설정")
        XCTAssertEqual(store.appLanguage, .korean)
    }

    func testApplyScoreWeightPresetPersistsToStore() throws {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        viewModel.applyScoreWeightPreset(.terminalHeavy)

        let saved = try XCTUnwrap(store.scoreWeightsData)
        let decoded = try JSONDecoder().decode(ScoreWeights.self, from: saved)
        XCTAssertEqual(decoded, .terminalHeavy)
        XCTAssertEqual(viewModel.scoreWeightPreset, .terminalHeavy)
    }

    func testRestoresScoreWeightsFromStore() throws {
        let store = InMemoryPreferencesStore()
        store.scoreWeightsData = try JSONEncoder().encode(ScoreWeights.ideHeavy)

        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        XCTAssertEqual(viewModel.scoreWeights, .ideHeavy)
        XCTAssertEqual(viewModel.scoreWeightPreset, .ideHeavy)
    }

    func testUpdateFeaturePreferencesPersistsToStore() throws {
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        let prefs = FontFeaturePreferences(
            ligaturesEnabled: false,
            zeroVariantEnabled: true,
            stylisticSetTags: ["ss01", "ss02"]
        )
        viewModel.updateFeaturePreferences(prefs, forFontID: "JetBrainsMono-Regular")

        let saved = try XCTUnwrap(store.fontFeaturePrefsData)
        let decoded = try JSONDecoder().decode([String: FontFeaturePreferences].self, from: saved)
        XCTAssertEqual(decoded["JetBrainsMono-Regular"], prefs)
    }

    func testRestoresFeaturePreferencesFromStore() throws {
        let store = InMemoryPreferencesStore()
        let saved: [String: FontFeaturePreferences] = [
            "FiraCode-Regular": FontFeaturePreferences(
                ligaturesEnabled: true,
                zeroVariantEnabled: false,
                stylisticSetTags: ["ss03"]
            )
        ]
        store.fontFeaturePrefsData = try JSONEncoder().encode(saved)
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: store
        )

        XCTAssertEqual(
            viewModel.featurePreferences(forFontID: "FiraCode-Regular"),
            saved["FiraCode-Regular"]
        )
    }


    func testRestoresFilterStateFromStore() {
        let store = InMemoryPreferencesStore()
        store.searchQuery = "noto"
        store.sidebarFilter = SidebarFilter.user.rawValue
        store.sortOption = SortOption.displayName.rawValue

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
        XCTAssertEqual(store.sortOption, SortOption.displayName.rawValue)
        XCTAssertEqual(store.sidebarFilter, SidebarFilter.favorites.rawValue)
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

    func testSystemAliasFontsCollapsedByDefault() async {
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
        await waitForLoad(viewModel)

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

    func testLoadFailureSetsErrorState() async {
        enum TestError: Error { case failed }
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [], error: TestError.failed),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)

        XCTAssertNotNil(viewModel.loadErrorMessage)
        XCTAssertTrue(viewModel.filteredFonts.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testFiltersBySearchKeyword() async {
        let fonts = [
            FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular]),
            FontItem.sample(id: "2", familyName: "PingFang SC", source: .system, styleTags: [.regular])
        ]
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()

        await waitForLoad(viewModel)
        viewModel.searchQuery = "ping"
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.familyName), ["PingFang SC"])
    }

    func testClearAllFiltersAlsoResetsGlyphCoverageQuery() {
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: InMemoryPreferencesStore()
        )
        viewModel.updateGlyphCoverageQuery("你好")
        XCTAssertEqual(viewModel.glyphCoverageQuery, "你好")

        viewModel.clearAllFilters()
        XCTAssertEqual(viewModel.glyphCoverageQuery, "")
    }

    func testGlyphCoverageIncludedInActiveFilterSummary() {
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: []),
            preferencesStore: InMemoryPreferencesStore()
        )
        XCTAssertEqual(viewModel.activeFilterSummary, viewModel.tr(.noFilters))
        viewModel.updateGlyphCoverageQuery("你好")
        XCTAssertTrue(viewModel.activeFilterSummary.contains(viewModel.tr(.filterGlyphCoverage)))
    }

    func testFiltersBySourceAndStyle() async {
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

        await waitForLoad(viewModel)
        viewModel.selectedSource = .user
        viewModel.selectedStyle = .bold
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.count, 1)
        XCTAssertEqual(viewModel.filteredFonts.first?.id, "2")
    }

    func testProgrammingModuleShowsOnlyMonospacedProgrammingCandidates() async {
        let coding = FontItem(
            id: "mono",
            familyName: "Mono",
            postScriptName: "Mono-Regular",
            displayName: "Mono",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile.empty.withMonospaced(true)
        )
        let decorative = FontItem(
            id: "display",
            familyName: "Display",
            postScriptName: "Display-Regular",
            displayName: "Display",
            source: .user,
            styleTags: [.regular],
            programming: ProgrammingProfile.empty.withMonospaced(false)
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [coding, decorative]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.updateWorkspaceModule(.programming)
        viewModel.updateSidebarFilter(.all)

        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["mono"])
    }

    func testProgrammingModuleDefaultsToRecommendedAndProgrammingSort() async {
        let coding = FontItem.sample(
            id: "mono",
            familyName: "Mono",
            source: .user,
            styleTags: [.regular, .monospace]
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [coding]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.updateWorkspaceModule(.programming)

        XCTAssertEqual(viewModel.sidebarFilter, .recommendedForCode)
        XCTAssertEqual(viewModel.sortOption, .programmingFit)
    }

    func testRecommendedForCodeFilterUsesProgrammingSignals() async {
        let recommended = FontItem(
            id: "recommended",
            familyName: "Recommended",
            postScriptName: "Recommended-Regular",
            displayName: "Recommended",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: true,
                availableStylisticSets: [],
                hasZeroVariant: true,
                hasPowerlineGlyphs: false,
                hasNerdFontGlyphs: false,
                hasBoxDrawing: true,
                coverageBuckets: [.latinExtended, .cyrillic, .greek],
                isVariableFont: false
            ),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.1, uniformWidth: true, confusableDistances: [:])
        )
        let avoid = FontItem(
            id: "avoid",
            familyName: "Avoid",
            postScriptName: "Avoid-Regular",
            displayName: "Avoid",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: FontMetricsSample(asciiAdvanceVariance: 1.8, uniformWidth: false, confusableDistances: [:])
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [recommended, avoid]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.updateWorkspaceModule(.programming)
        viewModel.updateSidebarFilter(.recommendedForCode)
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["recommended"])

        viewModel.updateSidebarFilter(.avoidForCode)
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["avoid"])
    }

    func testFavoriteTogglePersistsState() async {
        let item = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [item]),
            preferencesStore: store
        )

        viewModel.load()

        await waitForLoad(viewModel)
        viewModel.toggleFavorite(item)

        XCTAssertTrue(viewModel.favoriteIDs.contains(item.id))
        XCTAssertTrue(store.favoriteIDs.contains(item.id))
    }

    func testSelectingFontAddsToRecentsWithoutDuplicates() async {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let second = FontItem.sample(id: "2", familyName: "Avenir", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first, second]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()

        await waitForLoad(viewModel)
        viewModel.selectFont(first)
        viewModel.selectFont(second)
        viewModel.selectFont(first)

        XCTAssertEqual(viewModel.recentFontIDs, ["1", "2"])
    }

    func testRecentsFilterUsesRecencyOrder() async {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let second = FontItem.sample(id: "2", familyName: "Avenir", source: .system, styleTags: [.regular])
        let third = FontItem.sample(id: "3", familyName: "Helvetica", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first, second, third]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()

        await waitForLoad(viewModel)
        viewModel.selectFont(second)
        viewModel.selectFont(first)
        viewModel.selectFont(third)
        viewModel.sidebarFilter = .recents
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["3", "1", "2"])
    }

    func testSortByDisplayName() async {
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

        await waitForLoad(viewModel)
        viewModel.sortOption = .displayName
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.filteredFonts.map(\.displayName), ["Alpha", "Zebra"])
    }

    func testClearAllFiltersResetsState() async {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()

        await waitForLoad(viewModel)
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

    func testApplyPreviewPresetUpdatesPreviewText() async {
        let first = FontItem.sample(id: "1", familyName: "Arial", source: .system, styleTags: [.regular])
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [first]),
            preferencesStore: store
        )

        viewModel.load()

        await waitForLoad(viewModel)
        viewModel.applyPreviewPreset(.numeric)

        XCTAssertEqual(viewModel.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
        XCTAssertEqual(store.previewText, FontBrowserViewModel.PreviewPreset.numeric.text)
    }

    func testJapaneseAndKoreanPreviewPresetsProvideLocalizedText() {
        XCTAssertTrue(FontBrowserViewModel.PreviewPreset.japanese.text.contains("RootFont"))
        XCTAssertEqual(FontBrowserViewModel.PreviewPreset.japanese.title(language: .english), "Japanese")
        XCTAssertEqual(FontBrowserViewModel.PreviewPreset.korean.title(language: .korean), "한국어")
    }

    func testApplyFiltersDoesNotReloadManagedFontManifest() async {
        let activation = MockActivationService()
        activation.managedIDs = ["Managed"]
        let managed = FontItem.sample(
            id: "Managed",
            familyName: "Managed",
            source: .user,
            styleTags: [.regular]
        )
        let other = FontItem.sample(
            id: "Other",
            familyName: "Other",
            source: .user,
            styleTags: [.regular]
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [managed, other]),
            preferencesStore: InMemoryPreferencesStore(),
            activationService: activation
        )

        viewModel.load()
        await waitForLoad(viewModel)
        let countAfterInit = activation.managedFontIDsCallCount

        viewModel.applyFilters()
        viewModel.updateSearchQuery("oth")
        XCTAssertEqual(activation.managedFontIDsCallCount, countAfterInit)

        viewModel.updateSidebarFilter(.managed)
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["Managed"])

        activation.managedIDs.insert("Other")
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["Managed"])

        viewModel.refreshManagedFontState()
        XCTAssertEqual(activation.managedFontIDsCallCount, countAfterInit + 1)
        XCTAssertEqual(viewModel.filteredFonts.map(\.id).sorted(), ["Managed", "Other"])
    }

    func testSelectFontDoesNotRefilterWhenSidebarIsAll() async {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.regular]),
        ]
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)
        let before = viewModel.filteredFonts.map(\.id)

        viewModel.selectFont(fonts[1])
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), before)
    }

    func testApplyFiltersReflectsScoreWeightChanges() async {
        let monoHigh = FontItem(
            id: "MonoHigh",
            familyName: "Mono",
            postScriptName: "MonoHigh",
            displayName: "Mono High",
            source: .user,
            styleTags: [.regular, .monospace],
            programming: ProgrammingProfile(
                isMonospaced: true,
                hasProgrammingLigatures: true,
                availableStylisticSets: ["ss01"],
                hasZeroVariant: true,
                hasPowerlineGlyphs: true,
                hasNerdFontGlyphs: true,
                hasBoxDrawing: true,
                coverageBuckets: [.latinExtended, .cyrillic, .greek],
                isVariableFont: true
            ),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.05, uniformWidth: true, confusableDistances: [.iL1: 0.9])
        )
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: [monoHigh]),
            preferencesStore: InMemoryPreferencesStore()
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.updateSortOption(.programmingFit)
        viewModel.updateSidebarFilter(.all)

        let scoreBefore = viewModel.allFonts.first?.programmingScore?.total
        viewModel.applyScoreWeightPreset(.minimalist)
        let scoreAfter = viewModel.allFonts.first?.programmingScore?.total

        XCTAssertNotNil(scoreBefore)
        XCTAssertNotNil(scoreAfter)
        XCTAssertNotEqual(scoreBefore, scoreAfter)
    }

    func testManualCollectionPersistsAndFiltersFonts() async {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.regular]),
        ]
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: store
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.selectFont(fonts[0])
        viewModel.createManualCollection(named: "Work")
        XCTAssertNotNil(store.manualCollectionsData)

        guard let collection = viewModel.manualCollections.first else {
            return XCTFail("Expected manual collection")
        }
        XCTAssertEqual(collection.fontIDs, ["A"])

        viewModel.toggleFont(fonts[1], inCollection: collection.id)
        viewModel.selectManualCollection(collection)
        XCTAssertEqual(viewModel.filteredFonts.map(\.id).sorted(), ["A", "B"])
    }

    func testFontTagsPersistAndFilter() async {
        let fonts = [
            FontItem.sample(id: "A", familyName: "Alpha", source: .user, styleTags: [.regular]),
            FontItem.sample(id: "B", familyName: "Beta", source: .user, styleTags: [.regular]),
        ]
        let store = InMemoryPreferencesStore()
        let viewModel = FontBrowserViewModel(
            catalogService: MockCatalogService(fonts: fonts),
            preferencesStore: store
        )

        viewModel.load()
        await waitForLoad(viewModel)
        viewModel.selectFont(fonts[0])
        viewModel.createTag(named: "coding")
        XCTAssertNotNil(store.fontTagsData)
        XCTAssertTrue(viewModel.hasTag("coding", on: fonts[0]))

        viewModel.selectTag("coding")
        XCTAssertEqual(viewModel.filteredFonts.map(\.id), ["A"])
    }
}

private extension ProgrammingProfile {
    func withMonospaced(_ value: Bool) -> ProgrammingProfile {
        var copy = self
        copy.isMonospaced = value
        return copy
    }
}
