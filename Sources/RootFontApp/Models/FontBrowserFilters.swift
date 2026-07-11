import Foundation

/// Top-level filter enums used by `FontFilterEngine` and persisted UI state.
/// Kept outside `@MainActor` types so Swift 6 treats them as unconditionally Sendable.
enum WorkspaceModule: String, CaseIterable, Sendable {
    case library
    case programming
}

enum SidebarFilter: String, CaseIterable, Sendable {
    case all
    case system
    case user
    case favorites
    case recents
    case recommendedForCode
    case avoidForCode
    case managed
}

enum SortOption: String, CaseIterable, Identifiable, Sendable {
    case familyName
    case displayName
    case programmingFit

    var id: Self { self }
}
