import Foundation
@testable import RootFontApp

struct MockCatalogService: FontCatalogServiceProtocol {
    let fonts: [FontItem]
    let error: (any Error & Sendable)?

    init(fonts: [FontItem], error: (any Error & Sendable)? = nil) {
        self.fonts = fonts
        self.error = error
    }

    func loadFonts() throws -> [FontItem] {
        if let error {
            throw error
        }
        return fonts
    }
}

final class InMemoryPreferencesStore: PreferencesStoreProtocol {
    var favoriteIDs: Set<String> = []
    var recentFontIDs: [String] = []
    var previewText: String = "Preview"
    var previewSize: Double = 24

    private var storedLanguage: AppLanguage = .english
    var didChooseAppLanguage: Bool = false
    var appearanceMode: AppAppearanceMode = .system
    var showSystemAliasFonts: Bool = false
    var searchQuery: String = ""
    var sidebarFilter: String = "all"
    var sortOption: String = "familyName"
    var displayMode: String = "grid"
    var densityMode: String = "compact"
    var smartCollectionsData: Data?
    var scoreWeightsData: Data?

    var appLanguage: AppLanguage {
        get { didChooseAppLanguage ? storedLanguage : .english }
        set { storedLanguage = newValue }
    }
}

extension FontItem {
    static func sample(
        id: String,
        familyName: String,
        source: FontSource,
        styleTags: Set<FontStyleTag>
    ) -> FontItem {
        FontItem(
            id: id,
            familyName: familyName,
            postScriptName: familyName.replacingOccurrences(of: " ", with: "-"),
            displayName: familyName,
            source: source,
            styleTags: styleTags
        )
    }
}
