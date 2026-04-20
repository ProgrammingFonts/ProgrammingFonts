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
}
