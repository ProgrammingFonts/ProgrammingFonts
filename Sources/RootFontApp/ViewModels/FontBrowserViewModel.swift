import AppKit
import CoreText
import Foundation

@MainActor
final class FontBrowserViewModel: ObservableObject {
    enum WorkspaceModule: String, CaseIterable, Sendable {
        case library
        case programming
    }

    enum SidebarFilter: String, CaseIterable, Sendable {
        case all
        case system
        case user
        case favorites
        case recents
        case recommendedForCode
        case avoidForCode
    }

    enum SortOption: String, CaseIterable, Identifiable, Sendable {
        case familyName
        case displayName
        case programmingFit

        var id: Self { self }
    }

    private struct FilterSignature: Hashable {
        let searchQuery: String
        let coverageQuery: String
        let selectedSource: FontSource?
        let selectedStyle: FontStyleTag?
        let sidebarFilter: SidebarFilter
        let sortOption: SortOption
        let language: AppLanguage
        let showSystemAliasFonts: Bool
        let catalogEpoch: Int
        let favoritesSignature: Int
        let recentsSignature: Int
        let workspaceModule: WorkspaceModule
    }

    enum PreviewPreset: String, CaseIterable, Identifiable {
        case mixed
        case english
        case chinese
        case japanese
        case korean
        case numeric

        var id: Self { self }

        func title(language: AppLanguage) -> String {
            switch self {
            case .mixed:
                switch language {
                case .simplifiedChinese, .traditionalChinese: return "混合"
                case .japanese: return "混合"
                case .korean: return "혼합"
                case .english: return "Mixed"
                }
            case .english:
                switch language {
                case .simplifiedChinese, .traditionalChinese: return "英文"
                case .japanese: return "英語"
                case .korean: return "영문"
                case .english: return "English"
                }
            case .chinese:
                switch language {
                case .simplifiedChinese, .traditionalChinese: return "中文"
                case .japanese: return "中国語"
                case .korean: return "중문"
                case .english: return "Chinese"
                }
            case .japanese:
                switch language {
                case .simplifiedChinese: return "日语"
                case .traditionalChinese: return "日語"
                case .japanese: return "日本語"
                case .korean: return "일본어"
                case .english: return "Japanese"
                }
            case .korean:
                switch language {
                case .simplifiedChinese: return "韩语"
                case .traditionalChinese: return "韓語"
                case .japanese: return "韓国語"
                case .korean: return "한국어"
                case .english: return "Korean"
                }
            case .numeric:
                switch language {
                case .traditionalChinese: return "數字"
                case .simplifiedChinese: return "数字"
                case .japanese: return "数字"
                case .korean: return "숫자"
                case .english: return "Numeric"
                }
            }
        }

        var text: String {
            switch self {
            case .mixed:
                return "The quick brown fox 你好 こんにちは 안녕하세요 RootFont 123456"
            case .english:
                return "Sphinx of black quartz, judge my vow."
            case .chinese:
                return "你好，欢迎使用 RootFont。字重：常规/粗体，数字：2026。"
            case .japanese:
                return "こんにちは。RootFontで文字組みを確認しましょう。ひらがな・カタカナ・漢字 2026"
            case .korean:
                return "안녕하세요. RootFont에서 타이포그래피를 점검하세요. 한글·영문·숫자 2026"
            case .numeric:
                return "0123456789 +-*/ () [] {}"
            }
        }
    }

    private let catalogService: FontCatalogServiceProtocol
    private let fontImportService: FontImportServiceProtocol
    private let preferencesStore: PreferencesStoreProtocol
    private let maxRecents = 30
    private let maxCoverageCacheEntries = 2048
    private let backgroundFilterThreshold = 400
    private let filterResultCacheLimit = 8
    private var searchIndexByFontID: [String: FontFilterEngine.SearchIndexEntry] = [:]
    private var coverageSupportCache: [String: Bool] = [:]
    private var coverageCacheOrder: [String] = []
    private var catalogEpoch: Int = 0
    private var activeFilterTask: Task<Void, Never>?
    private var filterResultCache: [FilterSignature: [FontItem]] = [:]
    private var filterResultCacheOrder: [FilterSignature] = []

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
    @Published private(set) var loadErrorMessage: String?
    @Published private(set) var language: AppLanguage
    @Published private(set) var appearanceMode: AppAppearanceMode
    @Published private(set) var showSystemAliasFonts: Bool
    @Published private(set) var smartCollections: [SmartCollection] = []
    @Published private(set) var workspaceModule: WorkspaceModule = .library
    @Published private(set) var scoreWeights: ScoreWeights = .default
    @Published private(set) var scoreWeightPreset: ScoreWeightPreset = .default

    init(
        catalogService: FontCatalogServiceProtocol,
        fontImportService: FontImportServiceProtocol = FontImportService(),
        preferencesStore: PreferencesStoreProtocol
    ) {
        self.catalogService = catalogService
        self.fontImportService = fontImportService
        self.preferencesStore = preferencesStore
        self.favoriteIDs = preferencesStore.favoriteIDs
        self.recentFontIDs = preferencesStore.recentFontIDs
        self.previewText = preferencesStore.previewText
        self.previewSize = preferencesStore.previewSize
        self.language = preferencesStore.appLanguage
        self.appearanceMode = preferencesStore.appearanceMode
        self.showSystemAliasFonts = preferencesStore.showSystemAliasFonts
        self.searchQuery = preferencesStore.searchQuery
        self.sidebarFilter = SidebarFilter(rawValue: preferencesStore.sidebarFilter) ?? .all
        self.sortOption = SortOption(rawValue: preferencesStore.sortOption) ?? .familyName
        self.smartCollections = Self.decodeSmartCollections(preferencesStore.smartCollectionsData)
        if let data = preferencesStore.scoreWeightsData,
           let decoded = try? JSONDecoder().decode(ScoreWeights.self, from: data) {
            self.scoreWeights = decoded
            self.scoreWeightPreset = Self.bestMatchingPreset(for: decoded)
        }
    }

    func tr(_ key: L10nKey) -> String {
        L10n.tr(key, language: language)
    }

    func updateLanguage(_ value: AppLanguage) {
        language = value
        preferencesStore.appLanguage = value
        preferencesStore.didChooseAppLanguage = true
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
        preferencesStore.searchQuery = value
        applyFilters()
    }

    func updateGlyphCoverageQuery(_ value: String) {
        glyphCoverageQuery = value
        applyFilters()
    }

    func saveCurrentFiltersAsSmartCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = SmartCollection(
            name: trimmed,
            searchQuery: searchQuery,
            glyphCoverageQuery: glyphCoverageQuery,
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter
        )
        smartCollections.insert(item, at: 0)
        persistSmartCollections()
    }

    func applySmartCollection(_ collection: SmartCollection) {
        searchQuery = collection.searchQuery
        glyphCoverageQuery = collection.glyphCoverageQuery
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

    func updateSortOption(_ value: SortOption) {
        sortOption = value
        preferencesStore.sortOption = value.rawValue
        applyFilters()
    }

    func updateSidebarFilter(_ value: SidebarFilter) {
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
        recalculateProgrammingScores()
        applyFilters()
    }

    func updateScoreWeight(
        _ keyPath: WritableKeyPath<ScoreWeights, Double>,
        value: Double
    ) {
        scoreWeights[keyPath: keyPath] = value
        scoreWeightPreset = Self.bestMatchingPreset(for: scoreWeights)
        persistScoreWeights()
        recalculateProgrammingScores()
        applyFilters()
    }

    @discardableResult
    func importFonts(from urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        let count = fontImportService.registerFonts(at: urls)
        if count > 0 {
            load()
            return true
        }
        return false
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
        isLoading = true
        loadErrorMessage = nil
        let catalogService = self.catalogService
        Task.detached(priority: .userInitiated) { [weak self] in
            let loadedFonts: [FontItem]?
            let loadFailed: Bool
            do {
                loadedFonts = try catalogService.loadFonts()
                loadFailed = false
            } catch {
                loadedFonts = nil
                loadFailed = true
            }

            await MainActor.run {
                self?.applyLoadResult(fonts: loadedFonts, failed: loadFailed)
            }
        }
    }

    private func applyLoadResult(fonts: [FontItem]?, failed: Bool) {
        if failed {
            allFonts = []
            filteredFonts = []
            selectedFont = nil
            rebuildSearchIndex()
            clearCoverageCache()
            loadErrorMessage = tr(.catalogReadFailed)
        } else if let fonts {
            allFonts = fonts
            recalculateProgrammingScores()
            rebuildSearchIndex()
            clearCoverageCache()
            applyFilters()
            if selectedFont == nil {
                selectedFont = filteredFonts.first
            }
        }
        isLoading = false
    }

    var selectedFontVisible: Bool {
        guard let selectedFont else { return false }
        return filteredFonts.contains(selectedFont)
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
            parts.append("Programming")
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
        if !glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(tr(.filterGlyphCoverage))
        }
        return parts.isEmpty ? tr(.noFilters) : "\(tr(.filtersEnabledPrefix)) \(parts.joined(separator: " · "))"
    }

    func clearAllFilters() {
        searchQuery = ""
        selectedSource = nil
        selectedStyle = nil
        sidebarFilter = .all
        sortOption = .familyName
        glyphCoverageQuery = ""
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
        applyFilters()
    }

    func clearFavorites() {
        favoriteIDs = []
        preferencesStore.favoriteIDs = []
        applyFilters()
    }

    func selectFirstIfNeeded() {
        guard selectedFont == nil || !selectedFontVisible else { return }
        selectedFont = filteredFonts.first
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

    func applyFilters() {
        let signature = currentFilterSignature()

        if let cached = filterResultCache[signature] {
            commitFilterResult(cached, signature: signature, fromCache: true)
            return
        }

        activeFilterTask?.cancel()

        let inputs = currentFilterInputs()

        let filteredByModule = scopedFonts(for: allFonts)
        if filteredByModule.count <= backgroundFilterThreshold {
            let computed = FontFilterEngine.compute(
                fonts: filteredByModule,
                searchIndex: searchIndexByFontID,
                favoriteIDs: favoriteIDs,
                recentIDs: recentFontIDs,
                inputs: inputs
            )
            commitFilterResult(computed, signature: signature, fromCache: false)
            return
        }

        let fontsSnapshot = filteredByModule
        let searchIndexSnapshot = searchIndexByFontID
        let favoriteSnapshot = favoriteIDs
        let recentSnapshot = recentFontIDs

        activeFilterTask = Task { [weak self] in
            let computed = await Task.detached(priority: .userInitiated) {
                FontFilterEngine.compute(
                    fonts: fontsSnapshot,
                    searchIndex: searchIndexSnapshot,
                    favoriteIDs: favoriteSnapshot,
                    recentIDs: recentSnapshot,
                    inputs: inputs
                )
            }.value

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                guard self.currentFilterSignature() == signature else { return }
                self.commitFilterResult(computed, signature: signature, fromCache: false)
            }
        }
    }

    private func commitFilterResult(
        _ items: [FontItem],
        signature: FilterSignature,
        fromCache: Bool
    ) {
        if !fromCache {
            storeFilterResultInCache(items, for: signature)
        }
        filteredFonts = items
        selectFirstIfNeeded()
    }

    private func currentFilterInputs() -> FontFilterEngine.Inputs {
        FontFilterEngine.Inputs(
            preparedQuery: SearchMatcher.prepare(query: searchQuery),
            coverageQuery: glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter,
            sortOption: sortOption,
            language: language,
            showSystemAliasFonts: showSystemAliasFonts,
            scoreWeights: scoreWeights
        )
    }

    private func currentFilterSignature() -> FilterSignature {
        FilterSignature(
            searchQuery: searchQuery,
            coverageQuery: glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter,
            sortOption: sortOption,
            language: language,
            showSystemAliasFonts: showSystemAliasFonts,
            catalogEpoch: catalogEpoch,
            favoritesSignature: favoriteIDs.hashValue,
            recentsSignature: recentFontIDs.hashValue,
            workspaceModule: workspaceModule
        )
    }

    private func scopedFonts(for fonts: [FontItem]) -> [FontItem] {
        switch workspaceModule {
        case .library:
            return fonts
        case .programming:
            return fonts.filter { $0.programming?.isMonospaced == true }
        }
    }

    private func storeFilterResultInCache(_ items: [FontItem], for signature: FilterSignature) {
        if filterResultCache[signature] != nil {
            filterResultCacheOrder.removeAll { $0 == signature }
        }
        filterResultCache[signature] = items
        filterResultCacheOrder.append(signature)
        while filterResultCacheOrder.count > filterResultCacheLimit {
            let stale = filterResultCacheOrder.removeFirst()
            filterResultCache.removeValue(forKey: stale)
        }
    }

    private func invalidateFilterResultCache() {
        filterResultCache.removeAll(keepingCapacity: true)
        filterResultCacheOrder.removeAll(keepingCapacity: true)
    }

    /// Exposed for tests — returns true when the font resolved by
    /// `postScriptName` has glyphs for every non-whitespace character in
    /// `text`. Returns false if the font cannot be instantiated.
    func fontSupportsAllCharacters(postScriptName: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let cacheKey = "\(postScriptName)|\(trimmed)"
        if let cached = coverageSupportCache[cacheKey] {
            return cached
        }
        guard let font = NSFont(name: postScriptName, size: 16) else { return false }
        let supported = supportsAllCharacters(font: font, text: trimmed)
        coverageSupportCache[cacheKey] = supported
        coverageCacheOrder.append(cacheKey)
        trimCoverageCacheIfNeeded()
        return supported
    }

    private func rebuildSearchIndex() {
        searchIndexByFontID = Dictionary(uniqueKeysWithValues: allFonts.map { item in
            let names = item.searchableNames
            let normalized = names.map(SearchMatcher.normalize)
            let choseong = names.map(SearchMatcher.choseongProjection)
            return (item.id, FontFilterEngine.SearchIndexEntry(normalizedNames: normalized, choseongNames: choseong))
        })
        catalogEpoch &+= 1
        invalidateFilterResultCache()
    }

    private func clearCoverageCache() {
        coverageSupportCache.removeAll(keepingCapacity: true)
        coverageCacheOrder.removeAll(keepingCapacity: true)
    }

    private func trimCoverageCacheIfNeeded() {
        guard coverageCacheOrder.count > maxCoverageCacheEntries else { return }
        let overflow = coverageCacheOrder.count - maxCoverageCacheEntries
        guard overflow > 0 else { return }
        let staleKeys = coverageCacheOrder.prefix(overflow)
        for key in staleKeys {
            coverageSupportCache.removeValue(forKey: key)
        }
        coverageCacheOrder.removeFirst(overflow)
    }

    private func persistSmartCollections() {
        preferencesStore.smartCollectionsData = try? JSONEncoder().encode(smartCollections)
    }

    private static func decodeSmartCollections(_ data: Data?) -> [SmartCollection] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([SmartCollection].self, from: data)) ?? []
    }

    private func recalculateProgrammingScores() {
        let engine = ProgrammingScoreEngine(weights: scoreWeights)
        allFonts = FontCatalogService.attachProgrammingScores(allFonts, scoreEngine: engine)
    }

    private func persistScoreWeights() {
        preferencesStore.scoreWeightsData = try? JSONEncoder().encode(scoreWeights)
    }

    private static func bestMatchingPreset(for weights: ScoreWeights) -> ScoreWeightPreset {
        if weights == ScoreWeightPreset.default.weights { return .default }
        if weights == ScoreWeightPreset.terminalHeavy.weights { return .terminalHeavy }
        if weights == ScoreWeightPreset.ideHeavy.weights { return .ideHeavy }
        if weights == ScoreWeightPreset.minimalist.weights { return .minimalist }
        return .default
    }

    func preferredSearchDisplay(for item: FontItem) -> (primary: String, secondary: String) {
        let primaryDefault = item.familyName(for: language)
        let secondaryDefault = item.displayName(for: language)
        let prepared = SearchMatcher.prepare(query: searchQuery)
        guard !prepared.isEmpty else { return (primaryDefault, secondaryDefault) }
        if SearchMatcher.matches(haystack: primaryDefault, query: prepared.trimmed) {
            return (primaryDefault, secondaryDefault)
        }
        if SearchMatcher.matches(haystack: secondaryDefault, query: prepared.trimmed) {
            return (secondaryDefault, primaryDefault)
        }
        if let alias = item.searchableNames.first(where: { SearchMatcher.matches(haystack: $0, query: prepared.trimmed) }) {
            return (alias, secondaryDefault)
        }
        return (primaryDefault, secondaryDefault)
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
        updateRecents(with: item.id)
    }

    func toggleFavorite(_ item: FontItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
        preferencesStore.favoriteIDs = favoriteIDs
        applyFilters()
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
        applyFilters()
    }
}
