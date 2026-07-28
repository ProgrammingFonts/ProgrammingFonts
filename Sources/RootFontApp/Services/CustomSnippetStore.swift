import Foundation

struct CustomSnippet: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var text: String

    init(id: String = UUID().uuidString, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

enum CustomSnippetStore {
    static func decode(_ data: Data?) -> [CustomSnippet] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([CustomSnippet].self, from: data)) ?? []
    }

    static func encode(_ snippets: [CustomSnippet]) -> Data? {
        try? JSONEncoder().encode(snippets)
    }
}
