import Foundation

/// Owns the search-presentation cache and async build pipeline.
/// Extracted from `FontBrowserViewModel` to keep the view model focused
/// on UI state coordination.
@MainActor
final class FontSearchPresentationCoordinator {
    private var cache = FontSearchPresentationCache(limit: 320)
    private var buildTask: Task<Void, Never>?

    /// Returns the cached presentation for `item`, or builds one
    /// synchronously.
    func presentation(
        for item: FontItem,
        language: AppLanguage,
        preparedQuery: SearchMatcher.PreparedQuery
    ) -> FontSearchPresentation {
        if preparedQuery.isEmpty {
            return FontSearchPresentationBuilder.build(
                for: item,
                language: language,
                preparedQuery: preparedQuery
            )
        }
        if let cached = cache.value(for: item.id) {
            return cached
        }
        let built = FontSearchPresentationBuilder.build(
            for: item,
            language: language,
            preparedQuery: preparedQuery
        )
        cache.store(built, for: item.id)
        return built
    }

    /// Rebuilds presentations for `items` asynchronously, retaining only
    /// the visible window in the cache. Called after `applyFilters`.
    func rebuild(
        for items: [FontItem]?,
        language: AppLanguage,
        preparedQuery: SearchMatcher.PreparedQuery
    ) {
        guard !preparedQuery.isEmpty else {
            cache.clear()
            return
        }
        let token = Self.token(language: language, preparedQuery: preparedQuery)
        let sourceItems = items ?? []
        cache.resetIfNeeded(token: token)

        let sourceIDs = Set(sourceItems.map(\.id))
        cache.retain(fontIDs: sourceIDs)

        let toBuild = sourceItems.prefix(320).filter { cache.value(for: $0.id) == nil }
        guard !toBuild.isEmpty else { return }

        let batch = Array(toBuild)
        buildTask?.cancel()
        buildTask = Task { @MainActor [weak self] in
            let built: [(String, FontSearchPresentation)] = await Task.detached(priority: .userInitiated) {
                batch.map { item in
                    (item.id, FontSearchPresentationBuilder.build(
                        for: item,
                        language: language,
                        preparedQuery: preparedQuery
                    ))
                }
            }.value
            guard let self, !Task.isCancelled else { return }
            for (id, presentation) in built {
                self.cache.store(presentation, for: id)
            }
        }
    }

    func cancel() {
        buildTask?.cancel()
        buildTask = nil
    }

    func clear() {
        cache.clear()
    }

    private static func token(
        language: AppLanguage,
        preparedQuery: SearchMatcher.PreparedQuery
    ) -> String {
        "\(language.rawValue)|\(preparedQuery.normalized)|\(preparedQuery.choseong)"
    }
}
