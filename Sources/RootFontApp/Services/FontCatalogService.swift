import AppKit
import CoreText
import Foundation

protocol FontCatalogServiceProtocol: Sendable {
    func loadFonts() throws -> [FontItem]
}

struct FontCatalogService: FontCatalogServiceProtocol {
    enum CatalogError: Error {
        case unableToReadFontCatalog
    }

    private let styleResolver: FontStyleResolverProtocol

    init(styleResolver: FontStyleResolverProtocol = FontStyleResolver()) {
        self.styleResolver = styleResolver
    }

    func loadFonts() throws -> [FontItem] {
        guard let descriptors = CTFontManagerCopyAvailableFontURLs() as? [URL] else {
            throw CatalogError.unableToReadFontCatalog
        }

        var seen = Set<String>()
        var items: [FontItem] = []

        for url in descriptors {
            let postScriptName = url.deletingPathExtension().lastPathComponent
            guard !postScriptName.isEmpty else { continue }
            guard !seen.contains(postScriptName) else { continue }
            seen.insert(postScriptName)

            let nsFont = NSFont(name: postScriptName, size: 16) ?? NSFont.systemFont(ofSize: 16)
            let source: FontSource = url.path.contains("/System/Library/Fonts") ? .system : .user
            let styles = styleResolver.resolveStyleTags(for: nsFont)

            let ctFont = CTFontCreateWithName(postScriptName as CFString, 16, nil)
            let defaultFamily = nsFont.familyName ?? postScriptName
            let defaultDisplay = nsFont.displayName ?? postScriptName
            let localizedFamily = nativeLocalizedName(for: ctFont, nameID: kCTFontFamilyNameKey, fallback: defaultFamily)
            let localizedDisplay = nativeLocalizedName(for: ctFont, nameID: kCTFontFullNameKey, fallback: defaultDisplay)

            items.append(
                FontItem(
                    id: postScriptName,
                    familyName: defaultFamily,
                    postScriptName: postScriptName,
                    displayName: defaultDisplay,
                    source: source,
                    styleTags: styles,
                    localizedFamilyNames: localizedFamily,
                    localizedDisplayNames: localizedDisplay
                )
            )
        }

        return items.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }
    }

    /// Supported app languages we try to bucket localized names into. BCP47
    /// tags match `AppLanguage.rawValue`.
    private static let supportedLanguageTags: [String] = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

    /// Returns the font's *native* localized name, keyed by the BCP47 tag
    /// CoreText reports. macOS picks the best-matching name from the
    /// font's own name table based on the current user locale, which for
    /// CJK fonts is typically the font's native locale entry.
    private func nativeLocalizedName(for font: CTFont, nameID: CFString, fallback: String) -> [String: String] {
        var actualLanguage: Unmanaged<CFString>?
        guard let cfName = CTFontCopyLocalizedName(font, nameID, &actualLanguage) else {
            return [:]
        }
        let name = cfName as String
        guard !name.isEmpty, name != fallback else { return [:] }
        let matched = (actualLanguage?.takeRetainedValue() as String?) ?? ""
        guard let bucket = Self.bucket(for: matched) else { return [:] }
        return [bucket: name]
    }

    /// Maps a raw BCP47/IETF language tag returned by CoreText to one of
    /// our supported app-language buckets.
    private static func bucket(for rawTag: String) -> String? {
        let lower = rawTag.lowercased()
        if lower.hasPrefix("zh") {
            if lower.contains("hans") || lower.contains("cn") || lower.contains("sg") {
                return "zh-Hans"
            }
            if lower.contains("hant") || lower.contains("tw") || lower.contains("hk") || lower.contains("mo") {
                return "zh-Hant"
            }
            return "zh-Hans"
        }
        for tag in supportedLanguageTags where lower.hasPrefix(tag.lowercased()) {
            return tag
        }
        return nil
    }
}
