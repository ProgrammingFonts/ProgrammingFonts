import AppKit
import Foundation

protocol FontStyleResolverProtocol: Sendable {
    func resolveStyleTags(for font: NSFont) -> Set<FontStyleTag>
}

struct FontStyleResolver: FontStyleResolverProtocol {
    func resolveStyleTags(for font: NSFont) -> Set<FontStyleTag> {
        var tags = Set<FontStyleTag>()
        let traits = NSFontManager.shared.traits(of: font)

        if traits.contains(.boldFontMask) {
            tags.insert(.bold)
        }
        if traits.contains(.italicFontMask) {
            tags.insert(.italic)
        }
        if font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
            tags.insert(.monospace)
        }
        if tags.isEmpty {
            tags.insert(.regular)
        }

        return tags
    }
}
