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
        case .japanese:
            table = L10nJA.entries
        case .korean:
            table = L10nKO.entries
        case .french:
            table = L10nFR.entries
        case .german:
            table = L10nDE.entries
        case .spanish:
            table = L10nES.entries
        }
        return table[key] ?? L10nEN.entries[key] ?? String(describing: key)
    }
}
