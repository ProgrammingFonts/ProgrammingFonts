import Foundation

enum L10n {
    static func tr(_ key: L10nKey, language: AppLanguage) -> String {
        let table: [L10nKey: String]
        switch language {
        case .english:
            table = L10nEN.entries
        case .simplifiedChinese:
            table = L10nZHHans.entries
        case .traditionalChinese:
            table = L10nZHHant.entries
        }
        return table[key] ?? L10nEN.entries[key] ?? ""
    }
}
