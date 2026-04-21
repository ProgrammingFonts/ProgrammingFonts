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
        get { defaults.string(forKey: Keys.previewText) ?? "The quick brown fox jumps over the lazy dog 你好，RootFont" }
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
}
