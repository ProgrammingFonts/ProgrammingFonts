import AppKit
import Foundation

@MainActor
extension FontBrowserViewModel {
    var selectedFontVisible: Bool { selectedFont.map { filteredFontIDs.contains($0.id) } ?? false }
    var favoriteCount: Int { favoriteIDs.count }
    var recentCount: Int { recentFontIDs.count }

    var activeFilterSummary: String {
        var parts: [String] = []
        if workspaceModule == .programming { parts.append(tr(.moduleProgramming)) }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append(tr(.filterKeyword)) }
        if selectedSource != nil { parts.append(tr(.filterSource)) }
        if selectedStyle != nil { parts.append(tr(.filterStyle)) }
        if sidebarFilter != .all { parts.append(tr(.filterSidebar)) }
        if !trimmedCoverageQuery.isEmpty { parts.append(tr(.filterGlyphCoverage)) }
        if activeManualCollectionID != nil { parts.append(tr(.filterCollection)) }
        if activeTagName != nil { parts.append(tr(.filterTag)) }
        return parts.isEmpty ? tr(.noFilters) : "\(tr(.filtersEnabledPrefix)) \(parts.joined(separator: " · "))"
    }

    func clearAllFilters() {
        searchQuery = ""
        preparedSearchQuery = SearchMatcher.prepare(query: "")
        selectedSource = nil
        selectedStyle = nil
        sidebarFilter = .all
        sortOption = .familyName
        glyphCoverageQuery = ""
        trimmedCoverageQuery = ""
        activeManualCollectionID = nil
        activeTagName = nil
        preferencesController.saveSearchQuery("")
        preferencesController.saveSidebarFilter(.all)
        preferencesController.saveSortOption(.familyName)
        applyFilters()
    }

    func indexOfRecentFont(_ id: String) -> Int? { recentFontIDs.firstIndex(of: id) }
    func hasRenderablePreviewFont() -> Bool {
        selectedFont.flatMap { NSFont(name: $0.postScriptName, size: previewSize) } != nil
    }
    func hasPartialGlyphFallback(for text: String) -> Bool {
        guard let selectedFont, let font = NSFont(name: selectedFont.postScriptName, size: previewSize) else { return false }
        return !supportsAllCharacters(font: font, text: text)
    }
    func styleLabel(for item: FontItem) -> String {
        if item.styleTags.contains(.bold) { return tr(.bold) }
        if item.styleTags.contains(.italic) { return tr(.italic) }
        if item.styleTags.contains(.regular) { return tr(.regular) }
        return tr(.other)
    }
    func sourceLabel(for item: FontItem) -> String { item.source == .system ? tr(.system) : tr(.user) }
    func orderedRecentFonts() -> [FontItem] {
        let map = Dictionary(uniqueKeysWithValues: allFonts.map { ($0.id, $0) })
        return recentFontIDs.compactMap { map[$0] }
    }
    func orderedFavoriteFonts() -> [FontItem] {
        allFonts.filter { favoriteIDs.contains($0.id) }.sorted {
            $0.familyName.localizedCaseInsensitiveCompare($1.familyName) == .orderedAscending
        }
    }
    func clearRecents() {
        recentFontIDs = []
        preferencesController.saveRecents([])
        if sidebarFilter == .recents { applyFilters() }
    }
    func clearFavorites() {
        favoriteIDs = []
        preferencesController.saveFavorites([])
        if sidebarFilter == .favorites { applyFilters() }
    }
    func updatePreviewText(_ text: String) { previewText = text; preferencesController.savePreviewText(text) }
    func updatePreviewSize(_ size: Double) { previewSize = size; preferencesController.savePreviewSize(size) }
    func jumpToFavorites() { updateSidebarFilter(.favorites) }
    func jumpToRecents() { updateSidebarFilter(.recents) }
    func jumpToAllFonts() { updateSidebarFilter(.all) }
    func applyPreviewPreset(_ preset: PreviewPreset) { updatePreviewText(preset.text) }
    func refreshManagedFontState() {
        managedFontIDs = catalogCoordinator.managedFontIDs(using: activationService)
        applyFilters()
    }
}
