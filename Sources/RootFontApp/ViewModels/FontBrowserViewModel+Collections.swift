import Foundation

@MainActor
extension FontBrowserViewModel {
    func saveCurrentFiltersAsSmartCollection(named name: String) {
        guard let item = FontCollectionController.smartCollection(
            named: name, searchQuery: searchQuery, glyphCoverageQuery: glyphCoverageQuery,
            selectedSource: selectedSource, selectedStyle: selectedStyle, sidebarFilter: sidebarFilter
        ) else { return }
        smartCollections.insert(item, at: 0)
        persistSmartCollections()
    }

    func applySmartCollection(_ collection: SmartCollection) {
        activeManualCollectionID = nil
        activeTagName = nil
        searchQuery = collection.searchQuery
        preparedSearchQuery = SearchMatcher.prepare(query: collection.searchQuery)
        glyphCoverageQuery = collection.glyphCoverageQuery
        trimmedCoverageQuery = collection.glyphCoverageQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedSource = collection.selectedSource
        selectedStyle = collection.selectedStyle
        sidebarFilter = collection.sidebarFilter
        preferencesController.saveSearchQuery(searchQuery)
        preferencesController.saveSidebarFilter(sidebarFilter)
        applyFilters()
    }

    func removeSmartCollection(_ collection: SmartCollection) {
        smartCollections.removeAll { $0.id == collection.id }
        persistSmartCollections()
    }

    var userTagNames: [String] { sortedUserTagNames }

    func createManualCollection(named name: String) {
        guard let collection = FontCollectionController.manualCollection(
            named: name, selectedFontID: selectedFont?.id
        ) else { return }
        manualCollections.insert(collection, at: 0)
        persistManualCollections()
    }

    func removeManualCollection(_ collection: ManualCollection) {
        manualCollections.removeAll { $0.id == collection.id }
        if activeManualCollectionID == collection.id {
            activeManualCollectionID = nil
            applyFilters()
        }
        persistManualCollections()
    }

    func selectManualCollection(_ collection: ManualCollection) {
        activeManualCollectionID = collection.id
        activeTagName = nil
        applyFilters()
    }

    func clearManualCollectionFilter() {
        guard activeManualCollectionID != nil else { return }
        activeManualCollectionID = nil
        applyFilters()
    }

    func selectTag(_ tagName: String) {
        activeTagName = tagName
        activeManualCollectionID = nil
        applyFilters()
    }

    func clearTagFilter() {
        guard activeTagName != nil else { return }
        activeTagName = nil
        applyFilters()
    }

    func isFont(_ item: FontItem, inCollection collectionID: String) -> Bool {
        manualCollections.first { $0.id == collectionID }?.fontIDs.contains(item.id) ?? false
    }

    func toggleFont(_ item: FontItem, inCollection collectionID: String) {
        guard FontCollectionController.toggleFont(
            fontID: item.id, collectionID: collectionID, in: &manualCollections
        ) else { return }
        persistManualCollections()
        if activeManualCollectionID == collectionID { applyFilters() }
    }

    func hasTag(_ tag: String, on item: FontItem) -> Bool {
        fontTagAssignments[item.id]?.contains(tag) ?? false
    }

    func toggleTag(_ tag: String, on item: FontItem) {
        FontCollectionController.toggleTag(tag, fontID: item.id, assignments: &fontTagAssignments)
        rebuildTagIndex()
        persistFontTags()
        if activeTagName == tag { applyFilters() }
    }

    func createTag(named name: String) {
        guard let selectedFont,
              let tag = FontCollectionController.addTag(
                  named: name, fontID: selectedFont.id, assignments: &fontTagAssignments
              ) else { return }
        rebuildTagIndex()
        persistFontTags()
        if activeTagName == tag { applyFilters() }
    }
}
