import Foundation

enum FontPreviewPreset: String, CaseIterable, Identifiable {
    case mixed
    case english
    case chinese
    case japanese
    case korean
    case numeric

    var id: Self { self }

    var l10nKey: L10nKey {
        switch self {
        case .mixed: return .previewPresetMixed
        case .english: return .previewPresetEnglish
        case .chinese: return .previewPresetChinese
        case .japanese: return .previewPresetJapanese
        case .korean: return .previewPresetKorean
        case .numeric: return .previewPresetNumeric
        }
    }

    func title(language: AppLanguage) -> String {
        L10n.tr(l10nKey, language: language)
    }

    var text: String {
        switch self {
        case .mixed:
            return "The quick brown fox 你好 こんにちは 안녕하세요 rootfont 123456"
        case .english:
            return "Sphinx of black quartz, judge my vow."
        case .chinese:
            return "你好，欢迎使用 rootfont。字重：常规/粗体，数字：2026。"
        case .japanese:
            return "こんにちは。rootfontで文字組みを確認しましょう。ひらがな・カタカナ・漢字 2026"
        case .korean:
            return "안녕하세요. rootfont에서 타이포그래피를 점검하세요. 한글·영문·숫자 2026"
        case .numeric:
            return "0123456789 +-*/ () [] {}"
        }
    }
}
