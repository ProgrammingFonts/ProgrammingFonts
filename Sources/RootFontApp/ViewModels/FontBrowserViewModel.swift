import AppKit
import CoreText
import Foundation

/// Routes catalog load callbacks back to the main actor without capturing
/// `FontBrowserViewModel` in `@Sendable` closures passed to `Task.detached`.
private final class CatalogLoadBridge: @unchecked Sendable {
    weak var owner: FontBrowserViewModel?

    @MainActor
    func handlePartial(_ fonts: [FontItem]) {
        owner?.deliverPartialLoad(fonts)
    }

    @MainActor
    func handleProgress(_ progress: Double) {
        owner?.deliverLoadProgress(progress)
    }
}

@MainActor
final class FontBrowserViewModel: ObservableObject {
    typealias PreviewPreset = FontPreviewPreset

    private let catalogService: FontCatalogServiceProtocol
    private let fontImportService: FontImportServiceProtocol
    private let preferencesStore: PreferencesStoreProtocol
    let activationService: FontActivationServiceProtocol
    private let maxRecents = 30
    private let backgroundFilterThreshold = 400
    private var searchIndexByFontID: [String: FontFilterEngine.SearchIndexEntry] = [:]
    private var coverageCache = CoverageCache(limit: 2048)
    private var familyWeightCoverage: FamilyWeightCoverage?
    private var preparedSearchQuery = SearchMatcher.prepare(query: "")
    private var trimmedCoverageQuery = ""
    private var tagToFontIDs: [String: Set<String>] = [:]
    private var sortedUserTagNames: [String] = []
    private var indexedFontIDs: Set<String> = []
    private var catalogEpoch: Int = 0
    private var activeFilterTask: Task<Void, Never>?
    private let filterResultCache = FontFilterResultCache(limit: 8)
    private let searchPresentationCache = FontSearchPresentationCache(limit: 320)
    private var monospacedFonts: [FontItem] = []
    private var fontsByID: [String: FontItem] = [:]
    private var filteredFontIDs: Set<String> = []
    private let scoreCoordinator = ProgrammingScoreCoordinator()
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
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentFontIDs: [String]
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
    @Published private(set) var smartCollections: [SmartCollection] = []
    @Published private(set) var manualCollections: [ManualCollection] = []
    @Published private(set) var fontTagAssignments: [String: [String]] = [:]
    @Published var activeManualCollectionID: String?
    @Published var activeTagName: String?
    @Published private(set) var workspaceModule: WorkspaceModule = .library
    @Published private(set) var scoreWeights: ScoreWeights = .default
    @Published private(set) var scoreWeightPreset: ScoreWeightPreset = .default
    @Published private(set) var fontHealthReport: FontHealthReport = .empty
    @Published private(set) var customSnippets: [CustomSnippet] = []
    @Published private(set) var batchSelectedFontIDs: Set<String> = []
    private var fontFeaturePrefsMap: [String: FontFeaturePreferences] = [:]
    private var managedFontIDs: Set<String> = []
    private var catalogWatcher: FontCatalogWatcher?
    private var pendingCatalogReload = false

    init(
        catalogService: FontCatalogServiceProtocol,
        fontImportService: FontImportServiceProtocol = FontImportService(),
        preferencesStore: PreferencesStoreProtocol,
        activationService: FontActivationServiceProtocol = FontActivationService()
    ) {
        self.catalogService = catalogService
        self.fontImportService = fontImportService
        self.preferencesStore = preferencesStore
        self.activationService = activationService
        self.favoriteIDs = preferencesStore.favoriteIDs
        self.recentFontIDs = preferencesStore.recentFontIDs
        self.previewText = preferencesStore.previewText
        self.previewSize = preferencesStore.previewSize
        self.language = preferencesStore.appLanguage
        self.appearanceMode = preferencesStore.appearanceMode
        self.showSystemAliasFonts = preferencesStore.showSystemAliasFonts
        self.searchQuery = preferencesStore.searchQuery
        self.preparedSearchQuery = SearchMatcher.prepare(query: preferencesStore.searchQuery)
        self.sidebarFilter = SidebarFilter(rawValue: preferencesStore.sidebarFilter) ?? .all
        self.sortOption = SortOption(rawValue: preferencesStore.sortOption) ?? .familyName
        self.smartCollections = FontBrowserPreferencesCodec.decode(
            [SmartCollection].self,
            from: preferencesStore.smartCollectionsData,
            default: []
        )
        self.manualCollections = FontBrowserPreferencesCodec.decode(
            [ManualCollection].self,
            from: preferencesStore.manualCollectionsData,
            default: []
        )
        self.fontTagAssignments = FontBrowserPreferencesCodec.decode(
            [String: [String]].self,
            from: preferencesStore.fontTagsData,
            default: [:]
        )
        self.rebuildTagIndex()
        self.trimmedCoverageQuery = ""
        if let decoded: ScoreWeights = FontBrowserPreferencesCodec.decode(
            ScoreWeights?.self,
            from: preferencesStore.scoreWeightsData,
            default: nil
        ) {
            self.scoreWeights = decoded
            self.scoreWeightPreset = Self.bestMatchingPreset(for: decoded)
        }
        self.fontFeaturePrefsMap = FontBrowserPreferencesCodec.decode(
            [String: FontFeaturePreferences].self,
            from: preferencesStore.fontFeaturePrefsData,
            default: [:]
        )
        self.managedFontIDs = activationService.managedFontIDs()
        self.pendingSelectedFontID = preferencesStore.selectedFontID
        self.customSnippets = CustomSnippetStore.decode(preferencesStore.customSnippetsData)
    }

    func startCatalogWatcherIfNeeded() {
        guard preferencesStore.watchFontFoldersEnabled else { return }
        guard catalogWatcher == nil else { return }
        let urls = FontCatalogWatcher.defaultWatchURLs()
        catalogWatcher = FontCatalogWatcher(urls: urls) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isLoading {
                    self.pendingCatalogReload = true
                    return
                }
                self.load()
            }
        }
        catalogWatcher?.start()
    }

    func updateWatchFontFoldersEnabled(_ enabled: Bool) {
        preferencesStore.watchFontFoldersEnabled = enabled
        if enabled {
            startCatalogWatcherIfNeeded()
        } else {
            catalogWatcher?.stop()
            catalogWatcher = nil
        }
    }

    var watchFontFoldersEnabled: Bool {
        preferencesStore.watchFontFoldersEnabled
    }

    var batchSelectionCount: Int {
        batchSelectedFontIDs.count
    }

    func isBatchSelected(_ item: FontItem) -> Bool {
        batchSelectedFontIDs.contains(item.id)
    }

    func handleFontTap(_ item: FontItem, commandKey: Bool) {
        if commandKey {
            if batchSelectedFontIDs.contains(item.id) {
                batchSelectedFontIDs.remove(item.id)
            } else {
                batchSelectedFontIDs.insert(item.id)
            }
            selectFont(item)
            return
        }
        batchSelectedFontIDs = [item.id]
        selectFont(item)
    }

    func clearBatchSelection() {
        batchSelectedFontIDs.removeAll()
    }

    func batchSelectedFonts() -> [FontItem] {
        batchSelectedFontIDs.compactMap { fontsByID[$0] }
    }

    func batchToggleFavorite() {
        let items = batchSelectedFonts()
        guard !items.isEmpty else { return }
        let shouldFavorite = !items.allSatisfy { favoriteIDs.contains($0.id) }
        for item in items {
            if shouldFavorite {
                favoriteIDs.insert(item.id)
            } else {
                favoriteIDs.remove(item.id)
            }
        }
        preferencesStore.favoriteIDs = favoriteIDs
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
        preferencesStore.appLanguage = value
        preferencesStore.didChooseAppLanguage = true
        rebuildSearchPresentations(for: filteredFonts)
    }

    func updateAppearanceMode(_ value: AppAppearanceMode) {
        appearanceMode = value
        preferencesStore.appearanceMode = value
    }

    func updateShowSystemAliasFonts(_ value: Bool) {
        showSystemAliasFonts = value
        preferencesStore.showSystemAliasFonts = value
        applyFilters()
    }

    func updateSearchQuery(_ value: String) {
        searchQuery = value
        preparedSearchQuery = SearchMatcher.prepare(query: value)
        preferencesStore.searchQuery = value
        applyFilters()
    }

    func updateGlyphCoverageQuery(_ value: String) {
        glyphCoverageQuery = value
        trimmedCoverageQuery = value.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilters()
    }

    func saveCurrentFiltersAsSmartCollection(named name: String) {
        guard let item = FontCollectionController.smartCollection(
            named: name,
            searchQuery: searchQuery,
            glyphCoverageQuery: glyphCoverageQuery,
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter
        ) else { return }
        smartCollections.insert(item, at: 0)
        persistSmartCollections()
    }

    func applySmartCollection(_ collection: SmartCollection) {
        activeManualCollectionID = nil
        activeTagName = nil
        searchQuery = collection.searchQuery
        preparedSearchQuery = SearchMatcher.prepare(query: collection.searchQuery)
        glyphCoverageQuery = collection.glyphCoverageQuery
        trimmedCoverageQuery = collection.glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedSource = collection.selectedSource
        selectedStyle = collection.selectedStyle
        sidebarFilter = collection.sidebarFilter
        preferencesStore.searchQuery = searchQuery
        preferencesStore.sidebarFilter = sidebarFilter.rawValue
        applyFilters()
    }

    func removeSmartCollection(_ collection: SmartCollection) {
        smartCollections.removeAll(where: { $0.id == collection.id })
        persistSmartCollections()
    }

    var userTagNames: [String] {
        sortedUserTagNames
    }

    func createManualCollection(named name: String) {
        guard let collection = FontCollectionController.manualCollection(
            named: name,
            selectedFontID: selectedFont?.id
        ) else { return }
        manualCollections.insert(collection, at: 0)
        persistManualCollections()
    }

    func removeManualCollection(_ collection: ManualCollection) {
        manualCollections.removeAll(where: { $0.id == collection.id })
        if activeManualCollectionID == collection.id {
            activeManualCollectionID = nil
            applyFilters()
        }
        persistManualCollections()
    }

    func selectManualCollection(_ collection: ManualCollection) {
        activeManualCollectionID = collection.id
        activeTagName = nil
        applyFilters()
    }

    func clearManualCollectionFilter() {
        guard activeManualCollectionID != nil else { return }
        activeManualCollectionID = nil
        applyFilters()
    }

    func selectTag(_ tagName: String) {
        activeTagName = tagName
        activeManualCollectionID = nil
        applyFilters()
    }

    func clearTagFilter() {
        guard activeTagName != nil else { return }
        activeTagName = nil
        applyFilters()
    }

    func isFont(_ item: FontItem, inCollection collectionID: String) -> Bool {
        manualCollections.first(where: { $0.id == collectionID })?.fontIDs.contains(item.id) ?? false
    }

    func toggleFont(_ item: FontItem, inCollection collectionID: String) {
        guard FontCollectionController.toggleFont(
            fontID: item.id,
            collectionID: collectionID,
            in: &manualCollections
        ) else { return }
        persistManualCollections()
        if activeManualCollectionID == collectionID {
            applyFilters()
        }
    }

    func hasTag(_ tag: String, on item: FontItem) -> Bool {
        fontTagAssignments[item.id]?.contains(tag) ?? false
    }

    func toggleTag(_ tag: String, on item: FontItem) {
        FontCollectionController.toggleTag(
            tag,
            fontID: item.id,
            assignments: &fontTagAssignments
        )
        rebuildTagIndex()
        persistFontTags()
        if activeTagName == tag {
            applyFilters()
        }
    }

    func createTag(named name: String) {
        guard let selectedFont,
              let tag = FontCollectionController.addTag(
                  named: name,
                  fontID: selectedFont.id,
                  assignments: &fontTagAssignments
              ) else { return }
        rebuildTagIndex()
        persistFontTags()
        if activeTagName == tag {
            applyFilters()
        }
    }

    func updateSortOption(_ value: SortOption) {
        sortOption = value
        preferencesStore.sortOption = value.rawValue
        applyFilters()
    }

    func updateSidebarFilter(_ value: SidebarFilter) {
        activeManualCollectionID = nil
        activeTagName = nil
        sidebarFilter = value
        preferencesStore.sidebarFilter = value.rawValue
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
        preferencesStore.fontFeaturePrefsData = FontBrowserPreferencesCodec.encode(fontFeaturePrefsMap)
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
        guard !filteredFonts.isEmpty else { return }
        if let selectedFont,
           let index = filteredFonts.firstIndex(where: { $0.id == selectedFont.id }) {
            let nextIndex = min(max(0, index + offset), filteredFonts.count - 1)
            let next = filteredFonts[nextIndex]
            batchSelectedFontIDs = [next.id]
            selectFont(next)
        } else if let first = filteredFonts.first {
            batchSelectedFontIDs = [first.id]
            selectFont(first)
        }
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

    var fontHealthIssueCount: Int {
        fontHealthReport.issueCount
    }

    func fontItem(forID id: String) -> FontItem? {
        fontsByID[id]
    }

    func fontHealthIssues(for item: FontItem) -> Set<FontHealthIssueKind> {
        fontHealthReport.issueKinds(for: item.id)
    }

    func fontHealthIssueLabel(_ kind: FontHealthIssueKind) -> String {
        switch kind {
        case .broken: return tr(.fontHealthBroken)
        case .duplicate: return tr(.fontHealthDuplicates)
        }
    }

    func fontHealthSummaryText() -> String {
        String(
            format: tr(.fontHealthSummaryDetailed),
            fontHealthReport.brokenFontIDs.count,
            fontHealthReport.duplicateGroupCount,
            fontHealthReport.affectedFontIDs.count
        )
    }

    func fontHealthTextReport() -> String {
        FontHealthReportExporter.textReport(
            report: fontHealthReport,
            fontsByID: fontsByID,
            context: FontHealthReportContext(
                generatedAt: Date(),
                brokenLabel: tr(.fontHealthBroken),
                duplicateLabel: tr(.fontHealthDuplicates),
                duplicateGroupLabel: tr(.fontHealthDuplicateGroups),
                sourceSystemLabel: tr(.system),
                sourceUserLabel: tr(.user),
                styleLabel: styleLabel(for:),
                familyName: { $0.familyName(for: self.language) },
                displayName: { $0.displayName(for: self.language) }
            )
        )
    }

    func title(for sortOption: SortOption) -> String {
        switch sortOption {
        case .familyName:
            return tr(.byFamilyName)
        case .displayName:
            return tr(.byDisplayName)
        case .programmingFit:
            return tr(.byProgrammingFit)
        }
    }

    func load() {
        guard !isLoading else { return }
        cancelScoreRecalculation()
        FontURLIndex.shared.invalidate()
        managedFontIDs = activationService.managedFontIDs()
        isLoading = true
        loadProgress = 0
        loadErrorMessage = nil
        let catalogService = self.catalogService

        Task { @MainActor [weak self] in
            guard let self else { return }

            let bridge = CatalogLoadBridge()
            bridge.owner = self

            let onPartial: @Sendable ([FontItem]) -> Void = { partial in
                Task { @MainActor in
                    bridge.handlePartial(partial)
                }
            }
            let reportProgress: @Sendable (Double) -> Void = { progress in
                Task { @MainActor in
                    bridge.handleProgress(progress)
                }
            }

            let outcome = await FontCatalogLoadExecutor.execute(
                service: catalogService,
                onPartial: onPartial,
                reportProgress: reportProgress
            )

            self.applyLoadResult(fonts: outcome.fonts, failed: outcome.failed)
        }
    }

    fileprivate func deliverPartialLoad(_ fonts: [FontItem]) {
        applyPartialLoadResult(fonts: fonts)
    }

    fileprivate func deliverLoadProgress(_ progress: Double) {
        loadProgress = progress
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
        if pendingCatalogReload {
            pendingCatalogReload = false
            load()
        }
    }

    var selectedFontVisible: Bool {
        guard let selectedFont else { return false }
        return filteredFontIDs.contains(selectedFont.id)
    }

    var favoriteCount: Int {
        favoriteIDs.count
    }

    var recentCount: Int {
        recentFontIDs.count
    }

    var activeFilterSummary: String {
        var parts: [String] = []
        if workspaceModule == .programming {
            parts.append(tr(.moduleProgramming))
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(tr(.filterKeyword))
        }
        if selectedSource != nil {
            parts.append(tr(.filterSource))
        }
        if selectedStyle != nil {
            parts.append(tr(.filterStyle))
        }
        if sidebarFilter != .all {
            parts.append(tr(.filterSidebar))
        }
        if !trimmedCoverageQuery.isEmpty {
            parts.append(tr(.filterGlyphCoverage))
        }
        if activeManualCollectionID != nil {
            parts.append(tr(.filterCollection))
        }
        if activeTagName != nil {
            parts.append(tr(.filterTag))
        }
        return parts.isEmpty ? tr(.noFilters) : "\(tr(.filtersEnabledPrefix)) \(parts.joined(separator: " · "))"
    }

    func clearAllFilters() {
        searchQuery = ""
        preparedSearchQuery = SearchMatcher.prepare(query: "")
        selectedSource = nil
        selectedStyle = nil
        sidebarFilter = .all
        sortOption = .familyName
        glyphCoverageQuery = ""
        trimmedCoverageQuery = ""
        activeManualCollectionID = nil
        activeTagName = nil
        preferencesStore.searchQuery = ""
        preferencesStore.sidebarFilter = SidebarFilter.all.rawValue
        preferencesStore.sortOption = SortOption.familyName.rawValue
        applyFilters()
    }

    func indexOfRecentFont(_ id: String) -> Int? {
        recentFontIDs.firstIndex(of: id)
    }

    func hasRenderablePreviewFont() -> Bool {
        guard let postScript = selectedFont?.postScriptName else { return false }
        return NSFont(name: postScript, size: previewSize) != nil
    }

    func hasPartialGlyphFallback(for text: String) -> Bool {
        guard let postScript = selectedFont?.postScriptName,
              let font = NSFont(name: postScript, size: previewSize) else {
            return false
        }
        return !supportsAllCharacters(font: font, text: text)
    }

    func styleLabel(for item: FontItem) -> String {
        if item.styleTags.contains(.bold) { return tr(.bold) }
        if item.styleTags.contains(.italic) { return tr(.italic) }
        if item.styleTags.contains(.regular) { return tr(.regular) }
        return tr(.other)
    }

    func sourceLabel(for item: FontItem) -> String {
        item.source == .system ? tr(.system) : tr(.user)
    }

    func orderedRecentFonts() -> [FontItem] {
        let map = Dictionary(uniqueKeysWithValues: allFonts.map { ($0.id, $0) })
        return recentFontIDs.compactMap { map[$0] }
    }

    func orderedFavoriteFonts() -> [FontItem] {
        allFonts
            .filter { favoriteIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
            }
    }

    func clearRecents() {
        recentFontIDs = []
        preferencesStore.recentFontIDs = []
        if sidebarFilter == .recents {
            applyFilters()
        }
    }

    func clearFavorites() {
        favoriteIDs = []
        preferencesStore.favoriteIDs = []
        if sidebarFilter == .favorites {
            applyFilters()
        }
    }

    func updatePreviewText(_ text: String) {
        previewText = text
        preferencesStore.previewText = text
    }

    func updatePreviewSize(_ size: Double) {
        previewSize = size
        preferencesStore.previewSize = size
    }

    func jumpToFavorites() {
        updateSidebarFilter(.favorites)
    }

    func jumpToRecents() {
        updateSidebarFilter(.recents)
    }

    func jumpToAllFonts() {
        updateSidebarFilter(.all)
    }

    func applyPreviewPreset(_ preset: PreviewPreset) {
        updatePreviewText(preset.text)
    }

    func refreshManagedFontState() {
        managedFontIDs = activationService.managedFontIDs()
        applyFilters()
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

        if let cachedIDs = filterResultCache.value(for: signature) {
            commitFilterResult(fonts(matchingOrderedIDs: cachedIDs), signature: signature, fromCache: true)
            return
        }

        activeFilterTask?.cancel()

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

        let filteredByModule = scopedFonts(for: allFonts)
        let shouldDetach =
            filteredByModule.count > backgroundFilterThreshold
            || !trimmedCoverageQuery.isEmpty
        if !shouldDetach {
            let output = FontFilterEngine.compute(
                fonts: filteredByModule,
                searchIndex: searchIndexByFontID,
                favoriteIDs: favoriteIDs,
                recentIDs: recentFontIDs,
                inputs: inputs
            )
            mergeCoverageCacheUpdates(output.coverageCacheUpdates)
            commitFilterResult(output.fonts, signature: signature, fromCache: false)
            return
        }

        let fontsSnapshot = filteredByModule
        let searchIndexSnapshot = searchIndexByFontID
        let favoriteSnapshot = favoriteIDs
        let recentSnapshot = recentFontIDs

        activeFilterTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let output = await Task.detached(priority: .userInitiated) {
                FontFilterEngine.compute(
                    fonts: fontsSnapshot,
                    searchIndex: searchIndexSnapshot,
                    favoriteIDs: favoriteSnapshot,
                    recentIDs: recentSnapshot,
                    inputs: inputs
                )
            }.value

            guard !Task.isCancelled else { return }
            guard self.matchesFilterSignature(signature) else { return }
            self.mergeCoverageCacheUpdates(output.coverageCacheUpdates)
            self.commitFilterResult(output.fonts, signature: signature, fromCache: false)
        }
    }

    private func commitFilterResult(
        _ items: [FontItem],
        signature: FontFilterSignature,
        fromCache: Bool
    ) {
        if !fromCache {
            storeFilterResultInCache(items, for: signature)
        }
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

    private func matchesFilterSignature(_ signature: FontFilterSignature) -> Bool {
        currentFilterSignature() == signature
    }

    private func currentFilterSignature() -> FontFilterSignature {
        FontFilterSignature(
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
            manualCollectionSignature: activeManualCollectionFontIDs()?.hashValue ?? 0,
            tagFilterSignature: activeTagFilterFontIDs()?.hashValue ?? 0,
            fontHealthSignature: sidebarFilter == .fontHealth ? fontHealthReport.affectedFontIDs.hashValue : 0
        )
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

    private func storeFilterResultInCache(_ items: [FontItem], for signature: FontFilterSignature) {
        filterResultCache.store(fontIDs: items.map(\.id), for: signature)
    }

    private func fonts(matchingOrderedIDs ids: [String]) -> [FontItem] {
        ids.compactMap { fontsByID[$0] }
    }

    private func replaceAllFonts(_ fonts: [FontItem]) {
        allFonts = fonts
        fontsByID = Dictionary(uniqueKeysWithValues: fonts.map { ($0.id, $0) })
        fontHealthReport = FontHealthAnalyzer.analyze(fonts: fonts)
    }

    private func invalidateFilterResultCache() {
        filterResultCache.clear()
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

    private func rebuildTagIndex() {
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

    private func persistSmartCollections() {
        preferencesStore.smartCollectionsData = FontBrowserPreferencesCodec.encode(smartCollections)
    }

    private func persistManualCollections() {
        preferencesStore.manualCollectionsData = FontBrowserPreferencesCodec.encode(manualCollections)
    }

    private func persistFontTags() {
        preferencesStore.fontTagsData = FontBrowserPreferencesCodec.encode(fontTagAssignments)
    }

    private func persistCustomSnippets() {
        preferencesStore.customSnippetsData = CustomSnippetStore.encode(customSnippets)
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
        preferencesStore.scoreWeightsData = FontBrowserPreferencesCodec.encode(scoreWeights)
    }

    private static func bestMatchingPreset(for weights: ScoreWeights) -> ScoreWeightPreset {
        if weights == ScoreWeightPreset.default.weights { return .default }
        if weights == ScoreWeightPreset.terminalHeavy.weights { return .terminalHeavy }
        if weights == ScoreWeightPreset.ideHeavy.weights { return .ideHeavy }
        if weights == ScoreWeightPreset.minimalist.weights { return .minimalist }
        return .default
    }

    private func supportsAllCharacters(font: NSFont, text: String) -> Bool {
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
        preferencesStore.selectedFontID = item.id
        updateRecents(with: item.id)
    }

    func selectFirstIfNeeded() {
        if let pending = pendingSelectedFontID,
           let restored = fontsByID[pending],
           filteredFontIDs.contains(restored.id) {
            selectedFont = restored
            pendingSelectedFontID = nil
            return
        }
        guard selectedFont == nil || !selectedFontVisible else { return }
        selectedFont = filteredFonts.first
        if let selectedFont {
            preferencesStore.selectedFontID = selectedFont.id
        }
    }

    func toggleFavorite(_ item: FontItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
        preferencesStore.favoriteIDs = favoriteIDs
        if sidebarFilter == .favorites {
            applyFilters()
        }
    }

    func isFavorite(_ item: FontItem) -> Bool {
        favoriteIDs.contains(item.id)
    }

    private func updateRecents(with id: String) {
        recentFontIDs.removeAll(where: { $0 == id })
        recentFontIDs.insert(id, at: 0)
        if recentFontIDs.count > maxRecents {
            recentFontIDs = Array(recentFontIDs.prefix(maxRecents))
        }
        preferencesStore.recentFontIDs = recentFontIDs
        if sidebarFilter == .recents {
            applyFilters()
        }
    }
}
