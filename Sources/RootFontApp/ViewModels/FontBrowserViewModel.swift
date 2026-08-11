import AppKit
import CoreText
import Foundation

@MainActor
final class FontBrowserViewModel: ObservableObject {
    typealias PreviewPreset = FontPreviewPreset

    private let catalogService: FontCatalogServiceProtocol
    private let fontImportService: FontImportServiceProtocol
    let preferencesController: FontBrowserPreferencesController
    let activationService: FontActivationServiceProtocol
    private let maxRecents = 30
    private var searchIndexByFontID: [String: FontFilterEngine.SearchIndexEntry] = [:]
    private var coverageCache = CoverageCache(limit: 2048)
    private var familyWeightCoverage: FamilyWeightCoverage?
    var preparedSearchQuery = SearchMatcher.prepare(query: "")
    var trimmedCoverageQuery = ""
    private var tagToFontIDs: [String: Set<String>] = [:]
    var sortedUserTagNames: [String] = []
    private var indexedFontIDs: Set<String> = []
    private var catalogEpoch: Int = 0
    private let filterCoordinator = FontFilterCoordinator()
    private let searchPresentationCache = FontSearchPresentationCache(limit: 320)
    private var monospacedFonts: [FontItem] = []
    var fontsByID: [String: FontItem] = [:]
    var filteredFontIDs: Set<String> = []
    private let scoreCoordinator = ProgrammingScoreCoordinator()
    let catalogCoordinator = FontCatalogCoordinator()
    private var pendingSelectedFontID: String?

    @Published private(set) var allFonts: [FontItem] = []
    @Published private(set) var filteredFonts: [FontItem] = []
    @Published var selectedFont: FontItem?
    @Published var searchQuery = ""
    @Published var glyphCoverageQuery: String = ""
    @Published var selectedSource: FontSource?
    @Published var selectedStyle: FontStyleTag?
    @Published var sidebarFilter: SidebarFilter = .all
    @Published var sortOption: SortOption = .familyName
    @Published var favoriteIDs: Set<String>
    @Published var recentFontIDs: [String]
    @Published var previewText: String
    @Published var previewSize: Double
    @Published private(set) var isLoading = false
    @Published private(set) var isRecalculatingScores = false
    @Published private(set) var loadProgress: Double?
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var importBannerMessage: String?
    @Published private(set) var startupWarningMessage: String?
    @Published private(set) var searchFocusToken: UInt = 0
    @Published private(set) var language: AppLanguage
    @Published private(set) var appearanceMode: AppAppearanceMode
    @Published private(set) var showSystemAliasFonts: Bool
    @Published var smartCollections: [SmartCollection] = []
    @Published var manualCollections: [ManualCollection] = []
    @Published var fontTagAssignments: [String: [String]] = [:]
    @Published var activeManualCollectionID: String?
    @Published var activeTagName: String?
    @Published private(set) var workspaceModule: WorkspaceModule = .library
    @Published private(set) var scoreWeights: ScoreWeights = .default
    @Published private(set) var scoreWeightPreset: ScoreWeightPreset = .default
    @Published private(set) var fontHealthReport: FontHealthReport = .empty
    @Published private(set) var customSnippets: [CustomSnippet] = []
    @Published private(set) var batchSelectedFontIDs: Set<String> = []
    private var fontFeaturePrefsMap: [String: FontFeaturePreferences] = [:]
    var managedFontIDs: Set<String> = []

    init(
        catalogService: FontCatalogServiceProtocol,
        fontImportService: FontImportServiceProtocol = FontImportService(),
        preferencesStore: PreferencesStoreProtocol,
        activationService: FontActivationServiceProtocol = FontActivationService()
    ) {
        let preferencesController = FontBrowserPreferencesController(store: preferencesStore)
        let restored = preferencesController.restore()
        self.catalogService = catalogService
        self.fontImportService = fontImportService
        self.preferencesController = preferencesController
        self.activationService = activationService
        self.favoriteIDs = restored.favoriteIDs
        self.recentFontIDs = restored.recentFontIDs
        self.previewText = restored.previewText
        self.previewSize = restored.previewSize
        self.language = restored.language
        self.appearanceMode = restored.appearanceMode
        self.showSystemAliasFonts = restored.showSystemAliasFonts
        self.searchQuery = restored.searchQuery
        self.preparedSearchQuery = SearchMatcher.prepare(query: restored.searchQuery)
        self.sidebarFilter = restored.sidebarFilter
        self.sortOption = restored.sortOption
        self.smartCollections = restored.smartCollections
        self.manualCollections = restored.manualCollections
        self.fontTagAssignments = restored.fontTagAssignments
        self.rebuildTagIndex()
        self.trimmedCoverageQuery = ""
        if let decoded = restored.scoreWeights {
            self.scoreWeights = decoded
            self.scoreWeightPreset = Self.bestMatchingPreset(for: decoded)
        }
        self.fontFeaturePrefsMap = restored.featurePreferences
        self.managedFontIDs = catalogCoordinator.managedFontIDs(using: activationService)
        self.pendingSelectedFontID = restored.selectedFontID
        self.customSnippets = restored.customSnippets
    }

    func startCatalogWatcherIfNeeded() {
        guard preferencesController.watchFontFoldersEnabled else { return }
        let urls = FontCatalogWatcher.defaultWatchURLs()
        catalogCoordinator.startWatcher(urls: urls) { [weak self] in
            self?.load()
        }
    }

    func updateWatchFontFoldersEnabled(_ enabled: Bool) {
        preferencesController.watchFontFoldersEnabled = enabled
        if enabled {
            startCatalogWatcherIfNeeded()
        } else {
            catalogCoordinator.stopWatcher()
        }
    }

    var watchFontFoldersEnabled: Bool {
        preferencesController.watchFontFoldersEnabled
    }

    var batchSelectionCount: Int {
        batchSelectedFontIDs.count
    }

    func isBatchSelected(_ item: FontItem) -> Bool {
        batchSelectedFontIDs.contains(item.id)
    }

    func handleFontTap(_ item: FontItem, commandKey: Bool) {
        batchSelectedFontIDs = FontSelectionController.selectionAfterTap(
            fontID: item.id,
            commandKey: commandKey,
            current: batchSelectedFontIDs
        )
        selectFont(item)
    }

    func clearBatchSelection() {
        batchSelectedFontIDs.removeAll()
    }

    func batchSelectedFonts() -> [FontItem] {
        FontSelectionController.fonts(
            selectedIDs: batchSelectedFontIDs,
            fontsByID: fontsByID
        )
    }

    func batchToggleFavorite() {
        guard !batchSelectedFontIDs.isEmpty else { return }
        favoriteIDs = FontSelectionController.toggledFavorites(
            selectedIDs: batchSelectedFontIDs,
            favorites: favoriteIDs
        )
        preferencesController.saveFavorites(favoriteIDs)
        if sidebarFilter == .favorites {
            applyFilters()
        }
    }

    func batchApplyTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for item in batchSelectedFonts() {
            var tags = fontTagAssignments[item.id] ?? []
            if !tags.contains(trimmed) {
                tags.append(trimmed)
                fontTagAssignments[item.id] = tags.sorted()
            }
        }
        rebuildTagIndex()
        persistFontTags()
        if activeTagName == trimmed {
            applyFilters()
        }
    }

    func batchActivateForSession() {
        for item in batchSelectedFonts() where item.source == .user {
            try? activationService.activateForProcess(fontID: item.postScriptName)
        }
        refreshManagedFontState()
    }

    func tr(_ key: L10nKey) -> String {
        L10n.tr(key, language: language)
    }

    func updateLanguage(_ value: AppLanguage) {
        language = value
        preferencesController.saveLanguage(value)
        rebuildSearchPresentations(for: filteredFonts)
    }

    func updateAppearanceMode(_ value: AppAppearanceMode) {
        appearanceMode = value
        preferencesController.saveAppearance(value)
    }

    func updateShowSystemAliasFonts(_ value: Bool) {
        showSystemAliasFonts = value
        preferencesController.saveShowSystemAliasFonts(value)
        applyFilters()
    }

    func updateSearchQuery(_ value: String) {
        searchQuery = value
        preparedSearchQuery = SearchMatcher.prepare(query: value)
        preferencesController.saveSearchQuery(value)
        applyFilters()
    }

    func updateGlyphCoverageQuery(_ value: String) {
        glyphCoverageQuery = value
        trimmedCoverageQuery = value.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilters()
    }

    func updateSortOption(_ value: SortOption) {
        sortOption = value
        preferencesController.saveSortOption(value)
        applyFilters()
    }

    func updateSidebarFilter(_ value: SidebarFilter) {
        activeManualCollectionID = nil
        activeTagName = nil
        sidebarFilter = value
        preferencesController.saveSidebarFilter(value)
        applyFilters()
    }

    func updateWorkspaceModule(_ value: WorkspaceModule) {
        guard workspaceModule != value else { return }
        workspaceModule = value
        if value == .programming {
            updateSortOption(.programmingFit)
            if sidebarFilter == .all {
                updateSidebarFilter(.recommendedForCode)
                return
            }
        } else if sortOption == .programmingFit {
            updateSortOption(.familyName)
        }
        applyFilters()
    }

    func applyScoreWeightPreset(_ preset: ScoreWeightPreset) {
        scoreWeightPreset = preset
        scoreWeights = preset.weights
        persistScoreWeights()
        scheduleProgrammingScoreRecalculation()
    }

    func updateScoreWeight(
        _ keyPath: WritableKeyPath<ScoreWeights, Double>,
        value: Double
    ) {
        scoreWeights[keyPath: keyPath] = value
        scoreWeightPreset = Self.bestMatchingPreset(for: scoreWeights)
        persistScoreWeights()
        scheduleScoreWeightRefresh()
    }

    /// Applies a pending debounced score refresh immediately (tests and preset flows).
    func applyPendingScoreWeightRefresh() {
        scoreCoordinator.flushDebounce { [weak self] in
            self?.scheduleProgrammingScoreRecalculation()
        }
    }

    /// Waits until in-flight score recalculation (and debounce) finish. Used by tests.
    func waitForScoreRecalculation() async {
        await scoreCoordinator.waitUntilIdle()
    }

    private func scheduleProgrammingScoreRecalculation() {
        isRecalculatingScores = true
        let weights = scoreWeights
        let fontsSnapshot = allFonts
        let coverage = familyWeightCoverage ?? FamilyWeightCoverage.build(from: fontsSnapshot)
        scoreCoordinator.schedule(
            calculation: {
                FontCatalogService.attachProgrammingScores(
                    fontsSnapshot,
                    familyCoverage: coverage,
                    scoreEngine: ProgrammingScoreEngine(weights: weights)
                )
            },
            apply: { [weak self] updated in
                guard let self else { return }
                self.replaceAllFonts(updated)
                self.rebuildMonospacedFonts()
                self.catalogEpoch &+= 1
                self.invalidateFilterResultCache()
                self.applyFilters()
            },
            completion: { [weak self] in
                self?.isRecalculatingScores = false
            }
        )
    }

    private func scheduleScoreWeightRefresh() {
        scoreCoordinator.scheduleDebounced(delayNanoseconds: 220_000_000) { [weak self] in
            self?.scheduleProgrammingScoreRecalculation()
        }
    }

    private func cancelScoreRecalculation() {
        scoreCoordinator.cancel()
        isRecalculatingScores = false
    }

    func featurePreferences(forFontID fontID: String) -> FontFeaturePreferences? {
        fontFeaturePrefsMap[fontID]
    }

    func updateFeaturePreferences(_ prefs: FontFeaturePreferences, forFontID fontID: String) {
        fontFeaturePrefsMap[fontID] = prefs
        preferencesController.saveFeaturePreferences(fontFeaturePrefsMap)
    }

    @discardableResult
    func importFonts(from urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        let count = fontImportService.registerFonts(at: urls)
        if count > 0 {
            importBannerMessage = nil
            load()
            return true
        }
        importBannerMessage = tr(.importNoSupportedFonts)
        return false
    }

    func clearImportBanner() {
        importBannerMessage = nil
    }

    func reportActivationReconcileFailure() {
        startupWarningMessage = tr(.managedFontRecoveryFailed)
    }

    func clearStartupWarning() {
        startupWarningMessage = nil
    }

    func focusSearchField() {
        searchFocusToken &+= 1
    }

    func selectAdjacentFont(offset: Int) {
        guard let next = FontSelectionController.adjacentFont(
            to: selectedFont?.id,
            offset: offset,
            in: filteredFonts
        ) else { return }
        batchSelectedFontIDs = [next.id]
        selectFont(next)
    }

    func addCustomSnippet(name: String, text: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedText.isEmpty else { return }
        customSnippets.append(CustomSnippet(name: trimmedName, text: trimmedText))
        persistCustomSnippets()
    }

    func removeCustomSnippet(id: String) {
        customSnippets.removeAll { $0.id == id }
        persistCustomSnippets()
    }

    func load() {
        guard !isLoading else { return }
        cancelScoreRecalculation()
        FontURLIndex.shared.invalidate()
        managedFontIDs = catalogCoordinator.managedFontIDs(using: activationService)
        isLoading = true
        loadProgress = 0
        loadErrorMessage = nil
        catalogCoordinator.load(
            service: catalogService,
            onPartial: { [weak self] fonts in
                self?.applyPartialLoadResult(fonts: fonts)
            },
            onProgress: { [weak self] progress in
                self?.loadProgress = progress
            },
            completion: { [weak self] outcome in
                self?.applyLoadResult(fonts: outcome.fonts, failed: outcome.failed)
            }
        )
    }

    private func applyPartialLoadResult(fonts: [FontItem]) {
        replaceAllFonts(fonts)
        rebuildSearchIndex(force: false)
        applyFilters()
        if selectedFont == nil {
            selectedFont = filteredFonts.first
        }
    }

    private func applyLoadResult(fonts: [FontItem]?, failed: Bool) {
        if failed {
            cancelScoreRecalculation()
            replaceAllFonts([])
            filteredFonts = []
            filteredFontIDs = []
            selectedFont = nil
            rebuildSearchIndex(force: true)
            clearCoverageCache()
            loadErrorMessage = tr(.catalogReadFailed)
        } else if let fonts {
            let sameIDs = Set(fonts.map(\.id)) == indexedFontIDs
            replaceAllFonts(fonts)
            let needsRescore = scoreWeights != .default || fonts.contains(where: { $0.programmingScore == nil })
            if sameIDs {
                rebuildMonospacedFonts()
                catalogEpoch &+= 1
                invalidateFilterResultCache()
            } else {
                rebuildSearchIndex(force: true)
            }
            applyFilters()
            if selectedFont == nil {
                selectedFont = filteredFonts.first
            }
            if needsRescore {
                scheduleProgrammingScoreRecalculation()
            }
        }
        isLoading = false
        loadProgress = nil
    }

    func applyFilters() {
        // Keep prepared query in sync when callers set `searchQuery` directly
        // (tests); hot paths already update `preparedSearchQuery` themselves.
        if preparedSearchQuery.trimmed != searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) {
            preparedSearchQuery = SearchMatcher.prepare(query: searchQuery)
        }

        let manualIDs = activeManualCollectionFontIDs()
        let tagIDs = activeTagFilterFontIDs()
        let signature = FontFilterSignature(
            searchQuery: searchQuery,
            coverageQuery: trimmedCoverageQuery,
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter,
            sortOption: sortOption,
            language: language,
            showSystemAliasFonts: showSystemAliasFonts,
            catalogEpoch: catalogEpoch,
            favoritesSignature: sidebarFilter == .favorites ? favoriteIDs.hashValue : 0,
            recentsSignature: sidebarFilter == .recents ? recentFontIDs.hashValue : 0,
            workspaceModule: workspaceModule,
            managedSignature: sidebarFilter == .managed ? managedFontIDs.hashValue : 0,
            scoreWeightsSignature: filterUsesScoreWeights() ? scoreWeights.hashValue : 0,
            manualCollectionSignature: manualIDs?.hashValue ?? 0,
            tagFilterSignature: tagIDs?.hashValue ?? 0,
            fontHealthSignature: sidebarFilter == .fontHealth ? fontHealthReport.affectedFontIDs.hashValue : 0
        )

        let inputs = FontFilterEngine.Inputs(
            preparedQuery: preparedSearchQuery,
            coverageQuery: trimmedCoverageQuery,
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter,
            sortOption: sortOption,
            language: language,
            showSystemAliasFonts: showSystemAliasFonts,
            scoreWeights: scoreWeights,
            managedFontIDs: managedFontIDs,
            manualCollectionFontIDs: manualIDs,
            tagFilterFontIDs: tagIDs,
            fontHealthFontIDs: sidebarFilter == .fontHealth ? fontHealthReport.affectedFontIDs : nil,
            familyWeightCoverage: familyWeightCoverage,
            coverageSupportCache: coverageCache.values
        )

        let request = FontFilterCoordinator.Request(
            signature: signature,
            fonts: scopedFonts(for: allFonts),
            fontsByID: fontsByID,
            searchIndex: searchIndexByFontID,
            favoriteIDs: favoriteIDs,
            recentIDs: recentFontIDs,
            inputs: inputs
        )
        filterCoordinator.apply(request) { [weak self] result in
            self?.mergeCoverageCacheUpdates(result.coverageCacheUpdates)
            self?.commitFilterResult(result.fonts)
        }
    }

    private func commitFilterResult(_ items: [FontItem]) {
        filteredFonts = items
        filteredFontIDs = Set(items.map(\.id))
        batchSelectedFontIDs = batchSelectedFontIDs.intersection(filteredFontIDs)
        rebuildSearchPresentations(for: items)
        selectFirstIfNeeded()
    }

    private func activeManualCollectionFontIDs() -> Set<String>? {
        guard let id = activeManualCollectionID,
              let collection = manualCollections.first(where: { $0.id == id }) else {
            return nil
        }
        return Set(collection.fontIDs)
    }

    private func activeTagFilterFontIDs() -> Set<String>? {
        guard let tag = activeTagName else { return nil }
        return tagToFontIDs[tag]
    }

    private func filterUsesScoreWeights() -> Bool {
        switch sidebarFilter {
        case .recommendedForCode, .avoidForCode:
            return true
        case .recents:
            return false
        default:
            return sortOption == .programmingFit
        }
    }

    private func scopedFonts(for fonts: [FontItem]) -> [FontItem] {
        switch workspaceModule {
        case .library:
            return fonts
        case .programming:
            return monospacedFonts
        }
    }

    private func replaceAllFonts(_ fonts: [FontItem]) {
        allFonts = fonts
        fontsByID = Dictionary(uniqueKeysWithValues: fonts.map { ($0.id, $0) })
        fontHealthReport = FontHealthAnalyzer.analyze(fonts: fonts)
    }

    private func invalidateFilterResultCache() {
        filterCoordinator.invalidate()
    }

    /// Exposed for tests — returns true when the font resolved by
    /// `postScriptName` has glyphs for every non-whitespace character in
    /// `text`. Returns false if the font cannot be instantiated.
    func fontSupportsAllCharacters(postScriptName: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let cacheKey = "\(postScriptName)|\(trimmed)"
        if let cached = coverageCache.value(for: cacheKey) {
            return cached
        }
        guard let font = NSFontResolveCache.shared.font(postScriptName: postScriptName, size: 16) else { return false }
        let supported = supportsAllCharacters(font: font, text: trimmed)
        coverageCache.store(supported, for: cacheKey)
        return supported
    }

    private func rebuildSearchIndex(force: Bool = true) {
        let nextIDs = Set(allFonts.map(\.id))
        if !force, nextIDs == indexedFontIDs, !searchIndexByFontID.isEmpty {
            rebuildMonospacedFonts()
            catalogEpoch &+= 1
            invalidateFilterResultCache()
            return
        }

        searchIndexByFontID = Dictionary(uniqueKeysWithValues: allFonts.map { item in
            let names = item.searchableNames
            let normalized = names.map(SearchMatcher.normalize)
            let choseong = names.map(SearchMatcher.choseongProjection)
            return (item.id, FontFilterEngine.SearchIndexEntry(normalizedNames: normalized, choseongNames: choseong))
        })
        familyWeightCoverage = FamilyWeightCoverage.build(from: allFonts)
        indexedFontIDs = nextIDs
        rebuildMonospacedFonts()
        catalogEpoch &+= 1
        invalidateFilterResultCache()
    }

    func rebuildTagIndex() {
        let index = FontCollectionController.tagIndex(assignments: fontTagAssignments)
        tagToFontIDs = index.fontIDsByTag
        sortedUserTagNames = index.sortedNames
    }

    private func mergeCoverageCacheUpdates(_ updates: [String: Bool]) {
        coverageCache.merge(updates)
    }

    private func rebuildMonospacedFonts() {
        monospacedFonts = allFonts.filter { $0.programming?.isMonospaced == true }
    }

    private func clearCoverageCache() {
        coverageCache.clear()
    }

    func persistSmartCollections() {
        preferencesController.saveSmartCollections(smartCollections)
    }

    func persistManualCollections() {
        preferencesController.saveManualCollections(manualCollections)
    }

    func persistFontTags() {
        preferencesController.saveFontTags(fontTagAssignments)
    }

    private func persistCustomSnippets() {
        preferencesController.saveCustomSnippets(customSnippets)
    }

    func searchPresentation(for item: FontItem) -> FontSearchPresentation {
        if preparedSearchQuery.isEmpty {
            return FontSearchPresentationBuilder.build(
                for: item,
                language: language,
                preparedQuery: preparedSearchQuery
            )
        }
        if let cached = searchPresentationCache.value(for: item.id) {
            return cached
        }
        let built = FontSearchPresentationBuilder.build(
            for: item,
            language: language,
            preparedQuery: preparedSearchQuery
        )
        searchPresentationCache.store(built, for: item.id)
        return built
    }

    private func rebuildSearchPresentations(for items: [FontItem]? = nil) {
        guard !preparedSearchQuery.isEmpty else {
            searchPresentationCache.clear()
            return
        }
        let token = searchPresentationToken()
        let sourceItems = items ?? filteredFonts
        searchPresentationCache.resetIfNeeded(token: token)

        let sourceIDs = Set(sourceItems.map(\.id))
        searchPresentationCache.retain(fontIDs: sourceIDs)

        let lang = language
        let prepared = preparedSearchQuery
        for item in sourceItems.prefix(320) {
            if searchPresentationCache.value(for: item.id) != nil { continue }
            let built = FontSearchPresentationBuilder.build(
                for: item,
                language: lang,
                preparedQuery: prepared
            )
            searchPresentationCache.store(built, for: item.id)
        }
    }

    private func searchPresentationToken() -> String {
        "\(language.rawValue)|\(preparedSearchQuery.normalized)|\(preparedSearchQuery.choseong)"
    }

    func preferredSearchDisplay(for item: FontItem) -> (primary: String, secondary: String) {
        let presentation = searchPresentation(for: item)
        return (presentation.primary, presentation.secondary)
    }

    /// Exposed for list/grid highlighting so cells reuse the same prepared query.
    var preparedQueryForHighlight: SearchMatcher.PreparedQuery {
        preparedSearchQuery
    }

    private func persistScoreWeights() {
        preferencesController.saveScoreWeights(scoreWeights)
    }

    private static func bestMatchingPreset(for weights: ScoreWeights) -> ScoreWeightPreset {
        if weights == ScoreWeightPreset.default.weights { return .default }
        if weights == ScoreWeightPreset.terminalHeavy.weights { return .terminalHeavy }
        if weights == ScoreWeightPreset.ideHeavy.weights { return .ideHeavy }
        if weights == ScoreWeightPreset.minimalist.weights { return .minimalist }
        return .default
    }

    func supportsAllCharacters(font: NSFont, text: String) -> Bool {
        let filteredScalars = text.unicodeScalars.filter {
            !$0.properties.isWhitespace && !CharacterSet.controlCharacters.contains($0)
        }
        if filteredScalars.isEmpty { return true }

        let utf16Chars = Array(String(String.UnicodeScalarView(filteredScalars)).utf16)
        var glyphs = Array(repeating: CGGlyph(), count: utf16Chars.count)
        return CTFontGetGlyphsForCharacters(font as CTFont, utf16Chars, &glyphs, utf16Chars.count)
    }

    func selectFont(_ item: FontItem) {
        selectedFont = item
        if batchSelectedFontIDs.isEmpty {
            batchSelectedFontIDs = [item.id]
        }
        pendingSelectedFontID = nil
        preferencesController.saveSelectedFontID(item.id)
        updateRecents(with: item.id)
    }

    func selectFirstIfNeeded() {
        let resolution = FontSelectionController.resolvedSelection(
            pendingID: pendingSelectedFontID,
            current: selectedFont,
            visibleFonts: filteredFonts,
            fontsByID: fontsByID
        )
        if resolution.consumedPendingID {
            pendingSelectedFontID = nil
        }
        guard selectedFont?.id != resolution.font?.id else { return }
        selectedFont = resolution.font
        if let selectedFont {
            preferencesController.saveSelectedFontID(selectedFont.id)
        } else {
            preferencesController.saveSelectedFontID(nil)
        }
    }

    func toggleFavorite(_ item: FontItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
        preferencesController.saveFavorites(favoriteIDs)
        if sidebarFilter == .favorites {
            applyFilters()
        }
    }

    func isFavorite(_ item: FontItem) -> Bool {
        favoriteIDs.contains(item.id)
    }

    private func updateRecents(with id: String) {
        recentFontIDs = FontSelectionController.recents(
            adding: id,
            to: recentFontIDs,
            limit: maxRecents
        )
        preferencesController.saveRecents(recentFontIDs)
        if sidebarFilter == .recents {
            applyFilters()
        }
    }
}
