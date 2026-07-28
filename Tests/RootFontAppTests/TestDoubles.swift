import Foundation
@testable import RootFontApp

struct MockCatalogService: FontCatalogServiceProtocol {
    let fonts: [FontItem]
    let error: (any Error & Sendable)?

    init(fonts: [FontItem], error: (any Error & Sendable)? = nil) {
        self.fonts = fonts
        self.error = error
    }

    func loadFonts(
        onPartial: (@Sendable ([FontItem]) -> Void)?,
        reportProgress: (@Sendable (Double) -> Void)?
    ) throws -> [FontItem] {
        if let error {
            throw error
        }
        onPartial?(fonts)
        reportProgress?(1.0)
        return fonts
    }
}

final class MockActivationService: FontActivationServiceProtocol, @unchecked Sendable {
    var managedIDs: Set<String> = []
    private(set) var managedFontIDsCallCount = 0

    func activateForProcess(fontID: String) throws {
        managedIDs.insert(fontID)
    }

    func installForUser(fontID: String) throws {
        managedIDs.insert(fontID)
    }

    func uninstall(fontID: String) throws {
        managedIDs.remove(fontID)
    }

    func reconcile() throws {}

    func isManaged(fontID: String) -> Bool {
        managedIDs.contains(fontID)
    }

    func managedCount() -> Int {
        managedIDs.count
    }

    func managedFontIDs() -> Set<String> {
        managedFontIDsCallCount += 1
        return managedIDs
    }

    func managedFontsDirectoryURL() -> URL {
        URL(fileURLWithPath: "/tmp/rootfont-test-managed-fonts")
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
    var manualCollectionsData: Data?
    var fontTagsData: Data?
    var scoreWeightsData: Data?
    var fontFeaturePrefsData: Data?
    var selectedFontID: String?
    var customSnippetsData: Data?
    var watchFontFoldersEnabled: Bool = true

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
