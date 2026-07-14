import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: Self { self }

    var localeIdentifier: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        case .french:
            return "Français"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        }
    }

    var contributionFileName: String {
        switch self {
        case .english:
            return "en.swift"
        case .simplifiedChinese:
            return "zh-Hans.swift"
        case .traditionalChinese:
            return "zh-Hant.swift"
        case .japanese:
            return "ja.swift"
        case .korean:
            return "ko.swift"
        case .french:
            return "fr.swift"
        case .german:
            return "de.swift"
        case .spanish:
            return "es.swift"
        }
    }
}
