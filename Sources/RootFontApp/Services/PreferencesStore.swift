import Foundation

protocol PreferencesStoreProtocol: AnyObject {
    var favoriteIDs: Set<String> { get set }
    var recentFontIDs: [String] { get set }
    var previewText: String { get set }
    var previewSize: Double { get set }
    var appLanguage: AppLanguage { get set }
    var didChooseAppLanguage: Bool { get set }
    var appearanceMode: AppAppearanceMode { get set }
    var showSystemAliasFonts: Bool { get set }
    var searchQuery: String { get set }
    var sidebarFilter: String { get set }
    var sortOption: String { get set }
    var displayMode: String { get set }
    var densityMode: String { get set }
    var smartCollectionsData: Data? { get set }
    var manualCollectionsData: Data? { get set }
    var fontTagsData: Data? { get set }
    var scoreWeightsData: Data? { get set }
    var fontFeaturePrefsData: Data? { get set }
    var selectedFontID: String? { get set }
    var customSnippetsData: Data? { get set }
    var watchFontFoldersEnabled: Bool { get set }
}

final class PreferencesStore: PreferencesStoreProtocol {
    private let defaults: UserDefaults

    private enum Keys {
        static let favoriteIDs = "rootfont.favoriteIDs"
        static let recentFontIDs = "rootfont.recentFontIDs"
        static let previewText = "rootfont.previewText"
        static let previewSize = "rootfont.previewSize"
        static let appLanguage = "rootfont.appLanguage"
        static let didChooseAppLanguage = "rootfont.didChooseAppLanguage"
        static let appearanceMode = "rootfont.appearanceMode"
        static let showSystemAliasFonts = "rootfont.showSystemAliasFonts"
        static let searchQuery = "rootfont.searchQuery"
        static let sidebarFilter = "rootfont.sidebarFilter"
        static let sortOption = "rootfont.sortOption"
        static let displayMode = "rootfont.displayMode"
        static let densityMode = "rootfont.densityMode"
        static let smartCollectionsData = "rootfont.smartCollectionsData"
        static let manualCollectionsData = "rootfont.manualCollectionsData"
        static let fontTagsData = "rootfont.fontTagsData"
        static let scoreWeightsData = "rootfont.scoreWeightsData"
        static let fontFeaturePrefsData = "rootfont.fontFeaturePrefsData"
        static let selectedFontID = "rootfont.selectedFontID"
        static let customSnippetsData = "rootfont.customSnippetsData"
        static let watchFontFoldersEnabled = "rootfont.watchFontFoldersEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var favoriteIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.favoriteIDs) ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.favoriteIDs) }
    }

    var recentFontIDs: [String] {
        get { defaults.stringArray(forKey: Keys.recentFontIDs) ?? [] }
        set { defaults.set(newValue, forKey: Keys.recentFontIDs) }
    }

    var previewText: String {
        get { defaults.string(forKey: Keys.previewText) ?? "The quick brown fox jumps over the lazy dog 你好，rootfont" }
        set { defaults.set(newValue, forKey: Keys.previewText) }
    }

    var previewSize: Double {
        get {
            let value = defaults.double(forKey: Keys.previewSize)
            return value == 0 ? 32 : value
        }
        set { defaults.set(newValue, forKey: Keys.previewSize) }
    }

    var appLanguage: AppLanguage {
        get {
            guard didChooseAppLanguage,
                  let raw = defaults.string(forKey: Keys.appLanguage),
                  let lang = AppLanguage(rawValue: raw) else {
                return .english
            }
            return lang
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }

    var didChooseAppLanguage: Bool {
        get { defaults.bool(forKey: Keys.didChooseAppLanguage) }
        set { defaults.set(newValue, forKey: Keys.didChooseAppLanguage) }
    }

    var appearanceMode: AppAppearanceMode {
        get {
            guard let raw = defaults.string(forKey: Keys.appearanceMode),
                  let mode = AppAppearanceMode(rawValue: raw) else {
                return .system
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.appearanceMode) }
    }

    var showSystemAliasFonts: Bool {
        get { defaults.object(forKey: Keys.showSystemAliasFonts) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.showSystemAliasFonts) }
    }

    var searchQuery: String {
        get { defaults.string(forKey: Keys.searchQuery) ?? "" }
        set { defaults.set(newValue, forKey: Keys.searchQuery) }
    }

    var sidebarFilter: String {
        get { defaults.string(forKey: Keys.sidebarFilter) ?? "all" }
        set { defaults.set(newValue, forKey: Keys.sidebarFilter) }
    }

    var sortOption: String {
        get { defaults.string(forKey: Keys.sortOption) ?? "familyName" }
        set { defaults.set(newValue, forKey: Keys.sortOption) }
    }

    var displayMode: String {
        get { defaults.string(forKey: Keys.displayMode) ?? "grid" }
        set { defaults.set(newValue, forKey: Keys.displayMode) }
    }

    var densityMode: String {
        get { defaults.string(forKey: Keys.densityMode) ?? "compact" }
        set { defaults.set(newValue, forKey: Keys.densityMode) }
    }

    var smartCollectionsData: Data? {
        get { defaults.data(forKey: Keys.smartCollectionsData) }
        set { defaults.set(newValue, forKey: Keys.smartCollectionsData) }
    }

    var manualCollectionsData: Data? {
        get { defaults.data(forKey: Keys.manualCollectionsData) }
        set { defaults.set(newValue, forKey: Keys.manualCollectionsData) }
    }

    var fontTagsData: Data? {
        get { defaults.data(forKey: Keys.fontTagsData) }
        set { defaults.set(newValue, forKey: Keys.fontTagsData) }
    }

    var scoreWeightsData: Data? {
        get { defaults.data(forKey: Keys.scoreWeightsData) }
        set { defaults.set(newValue, forKey: Keys.scoreWeightsData) }
    }

    var fontFeaturePrefsData: Data? {
        get { defaults.data(forKey: Keys.fontFeaturePrefsData) }
        set { defaults.set(newValue, forKey: Keys.fontFeaturePrefsData) }
    }

    var selectedFontID: String? {
        get { defaults.string(forKey: Keys.selectedFontID) }
        set { defaults.set(newValue, forKey: Keys.selectedFontID) }
    }

    var customSnippetsData: Data? {
        get { defaults.data(forKey: Keys.customSnippetsData) }
        set { defaults.set(newValue, forKey: Keys.customSnippetsData) }
    }

    var watchFontFoldersEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.watchFontFoldersEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.watchFontFoldersEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.watchFontFoldersEnabled) }
    }
}
