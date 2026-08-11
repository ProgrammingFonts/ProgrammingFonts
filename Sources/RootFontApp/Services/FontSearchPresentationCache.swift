import Foundation

final class FontSearchPresentationCache {
    private let limit: Int
    private var values: [String: FontSearchPresentation] = [:]
    private var order = LRUOrder<String>()
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
        let staleIDs = values.keys.filter { !fontIDs.contains($0) }
        for staleID in staleIDs {
            values.removeValue(forKey: staleID)
            order.remove(staleID)
        }
    }

    func store(_ presentation: FontSearchPresentation, for fontID: String) {
        if values[fontID] != nil {
            order.remove(fontID)
        }
        values[fontID] = presentation
        order.touch(fontID)
        while order.count > limit, let stale = order.popTail() {
            values.removeValue(forKey: stale)
        }
    }

    func clear() {
        values.removeAll(keepingCapacity: true)
        order.clear()
        token = ""
    }
}
