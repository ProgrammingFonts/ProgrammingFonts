import Foundation

enum FontCollectionController {
    static func smartCollection(
        named name: String,
        searchQuery: String,
        glyphCoverageQuery: String,
        selectedSource: FontSource?,
        selectedStyle: FontStyleTag?,
        sidebarFilter: SidebarFilter
    ) -> SmartCollection? {
        let trimmed = normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        return SmartCollection(
            name: trimmed,
            searchQuery: searchQuery,
            glyphCoverageQuery: glyphCoverageQuery,
            selectedSource: selectedSource,
            selectedStyle: selectedStyle,
            sidebarFilter: sidebarFilter
        )
    }

    static func manualCollection(named name: String, selectedFontID: String?) -> ManualCollection? {
        let trimmed = normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        return ManualCollection(
            name: trimmed,
            fontIDs: selectedFontID.map { [$0] } ?? []
        )
    }

    @discardableResult
    static func toggleFont(
        fontID: String,
        collectionID: String,
        in collections: inout [ManualCollection]
    ) -> Bool {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else {
            return false
        }
        if collections[index].fontIDs.contains(fontID) {
            collections[index].fontIDs.removeAll { $0 == fontID }
        } else {
            collections[index].fontIDs.append(fontID)
        }
        return true
    }

    static func toggleTag(
        _ tag: String,
        fontID: String,
        assignments: inout [String: [String]]
    ) {
        var tags = assignments[fontID] ?? []
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        } else {
            tags.append(tag)
        }
        assignments[fontID] = tags.isEmpty ? nil : tags.sorted()
    }

    @discardableResult
    static func addTag(
        named name: String,
        fontID: String,
        assignments: inout [String: [String]]
    ) -> String? {
        let trimmed = normalizedName(name)
        guard !trimmed.isEmpty else { return nil }
        var tags = assignments[fontID] ?? []
        guard !tags.contains(trimmed) else { return nil }
        tags.append(trimmed)
        assignments[fontID] = tags.sorted()
        return trimmed
    }

    static func tagIndex(
        assignments: [String: [String]]
    ) -> (fontIDsByTag: [String: Set<String>], sortedNames: [String]) {
        var inverted: [String: Set<String>] = [:]
        for (fontID, tags) in assignments {
            for tag in tags {
                inverted[tag, default: []].insert(fontID)
            }
        }
        return (inverted, inverted.keys.sorted())
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
