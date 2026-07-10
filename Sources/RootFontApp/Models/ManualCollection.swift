import Foundation

struct ManualCollection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var fontIDs: [String]

    init(
        id: String = UUID().uuidString,
        name: String,
        fontIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fontIDs = fontIDs
    }
}
