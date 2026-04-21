import Foundation

struct SmartCollection: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var searchQuery: String
    var glyphCoverageQuery: String
    var selectedSource: FontSource?
    var selectedStyle: FontStyleTag?
    var sidebarFilterRawValue: String

    init(
        id: String = UUID().uuidString,
        name: String,
        searchQuery: String,
        glyphCoverageQuery: String,
        selectedSource: FontSource?,
        selectedStyle: FontStyleTag?,
        sidebarFilter: FontBrowserViewModel.SidebarFilter
    ) {
        self.id = id
        self.name = name
        self.searchQuery = searchQuery
        self.glyphCoverageQuery = glyphCoverageQuery
        self.selectedSource = selectedSource
        self.selectedStyle = selectedStyle
        self.sidebarFilterRawValue = sidebarFilter.rawValue
    }

    var sidebarFilter: FontBrowserViewModel.SidebarFilter {
        FontBrowserViewModel.SidebarFilter(rawValue: sidebarFilterRawValue) ?? .all
    }
}
