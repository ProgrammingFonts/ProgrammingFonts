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

            items.append(
                FontItem(
                    id: postScriptName,
                    familyName: nsFont.familyName ?? postScriptName,
                    postScriptName: postScriptName,
                    displayName: nsFont.displayName ?? postScriptName,
                    source: source,
                    styleTags: styles
                )
            )
        }

        return items.sorted { lhs, rhs in
            lhs.familyName.localizedCaseInsensitiveCompare(rhs.familyName) == .orderedAscending
        }
    }
}
