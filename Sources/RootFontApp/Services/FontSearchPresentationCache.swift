import Foundation

final class FontSearchPresentationCache {
    private let limit: Int
    private var values: [String: FontSearchPresentation] = [:]
    private var order: [String] = []
    private var token = ""

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func value(for fontID: String) -> FontSearchPresentation? {
        values[fontID]
    }

    func resetIfNeeded(token newToken: String) {
        guard token != newToken else { return }
        clear()
        token = newToken
    }

    func retain(fontIDs: Set<String>) {
        for staleID in values.keys where !fontIDs.contains(staleID) {
            values.removeValue(forKey: staleID)
            order.removeAll { $0 == staleID }
        }
    }

    func store(_ presentation: FontSearchPresentation, for fontID: String) {
        if values[fontID] != nil {
            order.removeAll { $0 == fontID }
        }
        values[fontID] = presentation
        order.append(fontID)
        while order.count > limit {
            let stale = order.removeFirst()
            values.removeValue(forKey: stale)
        }
    }

    func clear() {
        values.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
        token = ""
    }
}
