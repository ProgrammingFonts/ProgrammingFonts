import AppKit
import Foundation

@MainActor
final class FontBrowserViewModel: ObservableObject {
    enum SidebarFilter: String, CaseIterable {
        case all
        case system
        case user
        case favorites
        case recents
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case familyName
        case displayName

        var id: Self { self }
    }

    enum PreviewPreset: String, CaseIterable, Identifiable {
        case mixed
        case english
        case chinese
        case numeric

        var id: Self { self }

        func title(language: AppLanguage) -> String {
            switch self {
            case .mixed:
                return language == .traditionalChinese ? "混合" : (language == .simplifiedChinese ? "混合" : "Mixed")
            case .english:
                return language == .traditionalChinese ? "英文" : (language == .simplifiedChinese ? "英文" : "English")
            case .chinese:
                return language == .traditionalChinese ? "中文" : (language == .simplifiedChinese ? "中文" : "Chinese")
            case .numeric:
                return language == .traditionalChinese ? "數字" : (language == .simplifiedChinese ? "数字" : "Numeric")
            }
        }

        var text: String {
            switch self {
            case .mixed:
                return "The quick brown fox jumps over the lazy dog 你好，RootFont 123456"
            case .english:
                return "Sphinx of black quartz, judge my vow."
            case .chinese:
                return "你好，歡迎使用 RootFont 字體預覽。"
            case .numeric:
                return "0123456789 +-*/ () [] {}"
            }
        }
    }

    private let catalogService: FontCatalogServiceProtocol
    private let preferencesStore: PreferencesStoreProtocol
    private let maxRecents = 30

    @Published private(set) var allFonts: [FontItem] = []
    @Published private(set) var filteredFonts: [FontItem] = []
    @Published var selectedFont: FontItem?
    @Published var searchQuery = ""
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

    init(catalogService: FontCatalogServiceProtocol, preferencesStore: PreferencesStoreProtocol) {
        self.catalogService = catalogService
        self.preferencesStore = preferencesStore
        self.favoriteIDs = preferencesStore.favoriteIDs
        self.recentFontIDs = preferencesStore.recentFontIDs
        self.previewText = preferencesStore.previewText
        self.previewSize = preferencesStore.previewSize
        self.language = preferencesStore.appLanguage
        self.appearanceMode = preferencesStore.appearanceMode
        self.showSystemAliasFonts = preferencesStore.showSystemAliasFonts
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

    func title(for sortOption: SortOption) -> String {
        switch sortOption {
        case .familyName:
            return tr(.byFamilyName)
        case .displayName:
            return tr(.byDisplayName)
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
            loadErrorMessage = tr(.catalogReadFailed)
        } else if let fonts {
            allFonts = fonts
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
        return parts.isEmpty ? tr(.noFilters) : "\(tr(.filtersEnabledPrefix)) \(parts.joined(separator: " · "))"
    }

    func clearAllFilters() {
        searchQuery = ""
        selectedSource = nil
        selectedStyle = nil
        sidebarFilter = .all
        sortOption = .familyName
        applyFilters()
    }

    func indexOfRecentFont(_ id: String) -> Int? {
        recentFontIDs.firstIndex(of: id)
    }

    func hasRenderablePreviewFont() -> Bool {
        guard let postScript = selectedFont?.postScriptName else { return false }
        return NSFont(name: postScript, size: previewSize) != nil
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
        sidebarFilter = .favorites
        applyFilters()
    }

    func jumpToRecents() {
        sidebarFilter = .recents
        applyFilters()
    }

    func jumpToAllFonts() {
        sidebarFilter = .all
        applyFilters()
    }

    func applyPreviewPreset(_ preset: PreviewPreset) {
        updatePreviewText(preset.text)
    }

    private func sorted(_ fonts: [FontItem]) -> [FontItem] {
        switch sidebarFilter {
        case .recents:
            return fonts.sorted { lhs, rhs in
                let li = indexOfRecentFont(lhs.id) ?? Int.max
                let ri = indexOfRecentFont(rhs.id) ?? Int.max
                return li < ri
            }
        default:
            switch sortOption {
            case .familyName:
                return fonts.sorted {
                    $0.familyName.localizedCaseInsensitiveCompare($1.familyName) == .orderedAscending
                }
            case .displayName:
                return fonts.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            }
        }
    }

    func applyFilters() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let result = allFonts.filter { item in
            if !query.isEmpty {
                let inFamily = item.familyName.lowercased().contains(query)
                let inDisplay = item.displayName.lowercased().contains(query)
                if !inFamily && !inDisplay { return false }
            }

            if let selectedSource, item.source != selectedSource {
                return false
            }

            if let selectedStyle, !item.styleTags.contains(selectedStyle) {
                return false
            }

            switch sidebarFilter {
            case .all:
                return true
            case .system:
                return item.source == .system
            case .user:
                return item.source == .user
            case .favorites:
                return favoriteIDs.contains(item.id)
            case .recents:
                return recentFontIDs.contains(item.id)
            }
        }
        let presentationResult = showSystemAliasFonts ? result : collapseSystemAliasFonts(in: result)
        filteredFonts = sorted(presentationResult)
        selectFirstIfNeeded()
    }

    private func collapseSystemAliasFonts(in fonts: [FontItem]) -> [FontItem] {
        var seen = Set<String>()
        var collapsed: [FontItem] = []

        for item in fonts {
            let key = aliasFoldKey(for: item)
            if seen.insert(key).inserted {
                collapsed.append(item)
            }
        }
        return collapsed
    }

    private func aliasFoldKey(for item: FontItem) -> String {
        guard isSystemAliasFont(item) else {
            return item.id
        }
        return "systemAlias|\(item.familyName.lowercased())|\(primaryStyleTag(for: item).rawValue)"
    }

    private func isSystemAliasFont(_ item: FontItem) -> Bool {
        guard item.source == .system else { return false }
        let family = item.familyName.lowercased()
        let postScript = item.postScriptName.lowercased()
        return family.contains("applesystemui") || postScript.contains("applesystemui")
    }

    private func primaryStyleTag(for item: FontItem) -> FontStyleTag {
        if item.styleTags.contains(.bold) { return .bold }
        if item.styleTags.contains(.italic) { return .italic }
        if item.styleTags.contains(.regular) { return .regular }
        return .other
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
