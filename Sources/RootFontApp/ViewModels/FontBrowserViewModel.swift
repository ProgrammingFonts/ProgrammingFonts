import AppKit
import CoreText
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
    private let preferencesStore: PreferencesStoreProtocol
    private let maxRecents = 30

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
        self.searchQuery = preferencesStore.searchQuery
        self.sidebarFilter = SidebarFilter(rawValue: preferencesStore.sidebarFilter) ?? .all
        self.sortOption = SortOption(rawValue: preferencesStore.sortOption) ?? .familyName
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

    private func sorted(_ fonts: [FontItem]) -> [FontItem] {
        switch sidebarFilter {
        case .recents:
            return fonts.sorted { lhs, rhs in
                let li = indexOfRecentFont(lhs.id) ?? Int.max
                let ri = indexOfRecentFont(rhs.id) ?? Int.max
                return li < ri
            }
        default:
            let lang = language
            switch sortOption {
            case .familyName:
                return fonts.sorted {
                    $0.familyName(for: lang).localizedCaseInsensitiveCompare($1.familyName(for: lang)) == .orderedAscending
                }
            case .displayName:
                return fonts.sorted {
                    $0.displayName(for: lang).localizedCaseInsensitiveCompare($1.displayName(for: lang)) == .orderedAscending
                }
            }
        }
    }

    func applyFilters() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let coverageQuery = glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = allFonts.filter { item in
            if !query.isEmpty {
                let matched = item.searchableNames.contains { name in
                    SearchMatcher.matches(haystack: name, query: query)
                }
                if !matched { return false }
            }

            if let selectedSource, item.source != selectedSource {
                return false
            }

            if let selectedStyle, !item.styleTags.contains(selectedStyle) {
                return false
            }

            if !coverageQuery.isEmpty, !fontSupportsAllCharacters(postScriptName: item.postScriptName, text: coverageQuery) {
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

    /// Exposed for tests — returns true when the font resolved by
    /// `postScriptName` has glyphs for every non-whitespace character in
    /// `text`. Returns false if the font cannot be instantiated.
    func fontSupportsAllCharacters(postScriptName: String, text: String) -> Bool {
        guard let font = NSFont(name: postScriptName, size: 16) else { return false }
        return supportsAllCharacters(font: font, text: text)
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
