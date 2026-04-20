import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

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
        }
    }
}
