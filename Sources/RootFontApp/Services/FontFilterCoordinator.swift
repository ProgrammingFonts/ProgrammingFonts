import Foundation

@MainActor
final class FontFilterCoordinator {
    struct Request: Sendable {
        let signature: FontFilterSignature
        let fonts: [FontItem]
        let fontsByID: [String: FontItem]
        let searchIndex: [String: FontFilterEngine.SearchIndexEntry]
        let favoriteIDs: Set<String>
        let recentIDs: [String]
        let inputs: FontFilterEngine.Inputs
    }

    struct Result {
        let fonts: [FontItem]
        let coverageCacheUpdates: [String: Bool]
    }

    private let backgroundThreshold: Int
    private let resultCache: FontFilterResultCache
    private var activeTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(backgroundThreshold: Int = 400, cacheLimit: Int = 8) {
        self.backgroundThreshold = backgroundThreshold
        resultCache = FontFilterResultCache(limit: cacheLimit)
    }

    func apply(
        _ request: Request,
        completion: @escaping @MainActor (Result) -> Void
    ) {
        generation &+= 1
        let expectedGeneration = generation
        activeTask?.cancel()

        if let cachedIDs = resultCache.value(for: request.signature) {
            completion(
                Result(
                    fonts: cachedIDs.compactMap { request.fontsByID[$0] },
                    coverageCacheUpdates: [:]
                )
            )
            return
        }

        let shouldDetach = request.fonts.count > backgroundThreshold
            || !request.inputs.coverageQuery.isEmpty
        if !shouldDetach {
            complete(
                FontFilterEngine.compute(
                    fonts: request.fonts,
                    searchIndex: request.searchIndex,
                    favoriteIDs: request.favoriteIDs,
                    recentIDs: request.recentIDs,
                    inputs: request.inputs
                ),
                request: request,
                completion: completion
            )
            return
        }

        activeTask = Task { @MainActor [weak self] in
            let output = await Task.detached(priority: .userInitiated) {
                FontFilterEngine.compute(
                    fonts: request.fonts,
                    searchIndex: request.searchIndex,
                    favoriteIDs: request.favoriteIDs,
                    recentIDs: request.recentIDs,
                    inputs: request.inputs
                )
            }.value
            guard let self,
                  !Task.isCancelled,
                  expectedGeneration == self.generation else { return }
            self.complete(output, request: request, completion: completion)
            self.activeTask = nil
        }
    }

    func invalidate() {
        generation &+= 1
        activeTask?.cancel()
        activeTask = nil
        resultCache.clear()
    }

    private func complete(
        _ output: FontFilterEngine.ComputeOutput,
        request: Request,
        completion: @escaping @MainActor (Result) -> Void
    ) {
        resultCache.store(fontIDs: output.fonts.map(\.id), for: request.signature)
        completion(
            Result(
                fonts: output.fonts,
                coverageCacheUpdates: output.coverageCacheUpdates
            )
        )
    }
}
