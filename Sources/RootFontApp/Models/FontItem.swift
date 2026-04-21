import Foundation

enum FontSource: String, CaseIterable, Codable {
    case system
    case user
}

enum FontStyleTag: String, CaseIterable, Codable {
    case regular
    case bold
    case italic
    case other
}

struct FontItem: Identifiable, Hashable, Codable {
    let id: String
    let familyName: String
    let postScriptName: String
    let displayName: String
    let source: FontSource
    let styleTags: Set<FontStyleTag>
    /// Family name variants per BCP47 language tag (e.g. "ja", "ko", "zh-Hans").
    var localizedFamilyNames: [String: String]
    /// Display/full name variants per BCP47 language tag.
    var localizedDisplayNames: [String: String]

    init(
        id: String,
        familyName: String,
        postScriptName: String,
        displayName: String,
        source: FontSource,
        styleTags: Set<FontStyleTag>,
        localizedFamilyNames: [String: String] = [:],
        localizedDisplayNames: [String: String] = [:]
    ) {
        self.id = id
        self.familyName = familyName
        self.postScriptName = postScriptName
        self.displayName = displayName
        self.source = source
        self.styleTags = styleTags
        self.localizedFamilyNames = localizedFamilyNames
        self.localizedDisplayNames = localizedDisplayNames
    }

    /// Preferred family name for the given language, falling back to the
    /// canonical family name when no localized variant is available.
    func familyName(for language: AppLanguage) -> String {
        localizedFamilyNames[language.rawValue] ?? familyName
    }

    /// Preferred display name for the given language with fallback to the
    /// canonical display name.
    func displayName(for language: AppLanguage) -> String {
        localizedDisplayNames[language.rawValue] ?? displayName
    }

    /// Every distinct name this font is known by — used for CJK-friendly
    /// search so a user can find a font by any localized alias or its
    /// PostScript name.
    var searchableNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        add(familyName)
        add(displayName)
        add(postScriptName)
        for value in localizedFamilyNames.values { add(value) }
        for value in localizedDisplayNames.values { add(value) }
        return result
    }
}

extension Sequence where Element == FontItem {
    /// Sort fonts by their preferred family name for the given language,
    /// using a locale-aware case-insensitive comparison.
    func sortedByFamilyName(for language: AppLanguage) -> [FontItem] {
        sorted { lhs, rhs in
            lhs.familyName(for: language)
                .localizedCaseInsensitiveCompare(rhs.familyName(for: language)) == .orderedAscending
        }
    }
}
