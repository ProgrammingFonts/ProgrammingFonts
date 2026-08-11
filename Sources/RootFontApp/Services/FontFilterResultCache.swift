import Foundation

struct FontFilterSignature: Hashable, Sendable {
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
    private var order = LRUOrder<FontFilterSignature>()

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func value(for signature: FontFilterSignature) -> [String]? {
        let value = values[signature]
        #if DEBUG
        if value == nil {
            CacheDiagnostics.shared.recordMiss("filter-results")
        } else {
            CacheDiagnostics.shared.recordHit("filter-results")
        }
        #endif
        return value
    }

    func store(fontIDs: [String], for signature: FontFilterSignature) {
        if values[signature] != nil {
            order.remove(signature)
        }
        values[signature] = fontIDs
        order.touch(signature)
        while order.count > limit, let stale = order.popTail() {
            values.removeValue(forKey: stale)
            #if DEBUG
            CacheDiagnostics.shared.recordEviction("filter-results")
            #endif
        }
    }

    func clear() {
        values.removeAll(keepingCapacity: true)
        order.clear()
    }
}
