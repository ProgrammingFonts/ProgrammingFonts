import Foundation

enum FontSelectionController {
    static func resolvedSelection(
        pendingID: String?,
        current: FontItem?,
        visibleFonts: [FontItem],
        fontsByID: [String: FontItem]
    ) -> (font: FontItem?, consumedPendingID: Bool) {
        let visibleIDs = Set(visibleFonts.map(\.id))
        if let pendingID,
           let restored = fontsByID[pendingID],
           visibleIDs.contains(pendingID) {
            return (restored, true)
        }
        if let current, visibleIDs.contains(current.id) {
            return (current, false)
        }
        return (visibleFonts.first, false)
    }

    static func selectionAfterTap(
        fontID: String,
        commandKey: Bool,
        current: Set<String>
    ) -> Set<String> {
        guard commandKey else { return [fontID] }
        var updated = current
        if updated.remove(fontID) == nil {
            updated.insert(fontID)
        }
        return updated
    }

    static func fonts(
        selectedIDs: Set<String>,
        fontsByID: [String: FontItem]
    ) -> [FontItem] {
        selectedIDs.compactMap { fontsByID[$0] }
    }

    static func toggledFavorites(
        selectedIDs: Set<String>,
        favorites: Set<String>
    ) -> Set<String> {
        guard !selectedIDs.isEmpty else { return favorites }
        var updated = favorites
        let shouldFavorite = !selectedIDs.allSatisfy(updated.contains)
        if shouldFavorite {
            updated.formUnion(selectedIDs)
        } else {
            updated.subtract(selectedIDs)
        }
        return updated
    }

    static func recents(adding id: String, to current: [String], limit: Int) -> [String] {
        var updated = current.filter { $0 != id }
        updated.insert(id, at: 0)
        return Array(updated.prefix(max(0, limit)))
    }

    static func adjacentFont(
        to selectedID: String?,
        offset: Int,
        in fonts: [FontItem]
    ) -> FontItem? {
        guard !fonts.isEmpty else { return nil }
        guard let selectedID,
              let index = fonts.firstIndex(where: { $0.id == selectedID }) else {
            return fonts.first
        }
        let nextIndex = min(max(0, index + offset), fonts.count - 1)
        return fonts[nextIndex]
    }
}
