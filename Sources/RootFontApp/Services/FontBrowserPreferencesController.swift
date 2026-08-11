import Foundation

final class FontBrowserPreferencesController {
    struct RestoredState {
        let favoriteIDs: Set<String>
        let recentFontIDs: [String]
        let previewText: String
        let previewSize: Double
        let language: AppLanguage
        let appearanceMode: AppAppearanceMode
        let showSystemAliasFonts: Bool
        let searchQuery: String
        let sidebarFilter: SidebarFilter
        let sortOption: SortOption
        let smartCollections: [SmartCollection]
        let manualCollections: [ManualCollection]
        let fontTagAssignments: [String: [String]]
        let scoreWeights: ScoreWeights?
        let featurePreferences: [String: FontFeaturePreferences]
        let selectedFontID: String?
        let customSnippets: [CustomSnippet]
    }

    private let store: PreferencesStoreProtocol

    init(store: PreferencesStoreProtocol) {
        self.store = store
    }

    func restore() -> RestoredState {
        RestoredState(
            favoriteIDs: store.favoriteIDs,
            recentFontIDs: store.recentFontIDs,
            previewText: store.previewText,
            previewSize: store.previewSize,
            language: store.appLanguage,
            appearanceMode: store.appearanceMode,
            showSystemAliasFonts: store.showSystemAliasFonts,
            searchQuery: store.searchQuery,
            sidebarFilter: SidebarFilter(rawValue: store.sidebarFilter) ?? .all,
            sortOption: SortOption(rawValue: store.sortOption) ?? .familyName,
            smartCollections: decode([SmartCollection].self, from: store.smartCollectionsData, default: []),
            manualCollections: decode([ManualCollection].self, from: store.manualCollectionsData, default: []),
            fontTagAssignments: decode([String: [String]].self, from: store.fontTagsData, default: [:]),
            scoreWeights: decode(ScoreWeights?.self, from: store.scoreWeightsData, default: nil),
            featurePreferences: decode(
                [String: FontFeaturePreferences].self,
                from: store.fontFeaturePrefsData,
                default: [:]
            ),
            selectedFontID: store.selectedFontID,
            customSnippets: CustomSnippetStore.decode(store.customSnippetsData)
        )
    }

    var watchFontFoldersEnabled: Bool {
        get { store.watchFontFoldersEnabled }
        set { store.watchFontFoldersEnabled = newValue }
    }

    var displayMode: String {
        get { store.displayMode }
        set { store.displayMode = newValue }
    }
    var densityMode: String {
        get { store.densityMode }
        set { store.densityMode = newValue }
    }
    var listPreviewSize: Double {
        get { store.listPreviewSize }
        set { store.listPreviewSize = newValue }
    }

    func saveFavorites(_ value: Set<String>) { store.favoriteIDs = value }
    func saveRecents(_ value: [String]) { store.recentFontIDs = value }
    func savePreviewText(_ value: String) { store.previewText = value }
    func savePreviewSize(_ value: Double) { store.previewSize = value }
    func saveLanguage(_ value: AppLanguage) {
        store.appLanguage = value
        store.didChooseAppLanguage = true
    }
    func saveAppearance(_ value: AppAppearanceMode) { store.appearanceMode = value }
    func saveShowSystemAliasFonts(_ value: Bool) { store.showSystemAliasFonts = value }
    func saveSearchQuery(_ value: String) { store.searchQuery = value }
    func saveSidebarFilter(_ value: SidebarFilter) { store.sidebarFilter = value.rawValue }
    func saveSortOption(_ value: SortOption) { store.sortOption = value.rawValue }
    func saveSmartCollections(_ value: [SmartCollection]) {
        store.smartCollectionsData = FontBrowserPreferencesCodec.encode(value)
    }
    func saveManualCollections(_ value: [ManualCollection]) {
        store.manualCollectionsData = FontBrowserPreferencesCodec.encode(value)
    }
    func saveFontTags(_ value: [String: [String]]) {
        store.fontTagsData = FontBrowserPreferencesCodec.encode(value)
    }
    func saveScoreWeights(_ value: ScoreWeights) {
        store.scoreWeightsData = FontBrowserPreferencesCodec.encode(value)
    }
    func saveFeaturePreferences(_ value: [String: FontFeaturePreferences]) {
        store.fontFeaturePrefsData = FontBrowserPreferencesCodec.encode(value)
    }
    func saveSelectedFontID(_ value: String?) { store.selectedFontID = value }
    func saveCustomSnippets(_ value: [CustomSnippet]) {
        store.customSnippetsData = CustomSnippetStore.encode(value)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?, default fallback: T) -> T {
        FontBrowserPreferencesCodec.decode(type, from: data, default: fallback)
    }
}
