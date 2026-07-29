import Foundation

struct FontFilterSignature: Hashable {
    let searchQuery: String
    let coverageQuery: String
    let selectedSource: FontSource?
    let selectedStyle: FontStyleTag?
    let sidebarFilter: SidebarFilter
    let sortOption: SortOption
    let language: AppLanguage
    let showSystemAliasFonts: Bool
    let catalogEpoch: Int
    let favoritesSignature: Int
    let recentsSignature: Int
    let workspaceModule: WorkspaceModule
    let managedSignature: Int
    let scoreWeightsSignature: Int
    let manualCollectionSignature: Int
    let tagFilterSignature: Int
    let fontHealthSignature: Int
}

final class FontFilterResultCache {
    private let limit: Int
    private var values: [FontFilterSignature: [String]] = [:]
    private var order: [FontFilterSignature] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func value(for signature: FontFilterSignature) -> [String]? {
        values[signature]
    }

    func store(fontIDs: [String], for signature: FontFilterSignature) {
        if values[signature] != nil {
            order.removeAll { $0 == signature }
        }
        values[signature] = fontIDs
        order.append(signature)
        while order.count > limit {
            let stale = order.removeFirst()
            values.removeValue(forKey: stale)
        }
    }

    func clear() {
        values.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }
}
