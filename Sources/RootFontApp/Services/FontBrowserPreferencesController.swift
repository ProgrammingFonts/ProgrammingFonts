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

    private func decode<T: Decodable>(_ type: T.Type, from data: Data?, default fallback: T) -> T {
        FontBrowserPreferencesCodec.decode(type, from: data, default: fallback)
    }
}
