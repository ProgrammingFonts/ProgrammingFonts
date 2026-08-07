import Foundation

@MainActor
final class FontFilterCoordinator {
    typealias Compute = @Sendable (Request) -> FontFilterEngine.ComputeOutput

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
    private let compute: Compute
    private var activeTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(
        backgroundThreshold: Int = 400,
        cacheLimit: Int = 8,
        compute: @escaping Compute = { request in
            FontFilterEngine.compute(
                fonts: request.fonts,
                searchIndex: request.searchIndex,
                favoriteIDs: request.favoriteIDs,
                recentIDs: request.recentIDs,
                inputs: request.inputs
            )
        }
    ) {
        self.backgroundThreshold = backgroundThreshold
        resultCache = FontFilterResultCache(limit: cacheLimit)
        self.compute = compute
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
                compute(request),
                request: request,
                completion: completion
            )
            return
        }

        activeTask = Task { @MainActor [weak self] in
            guard let compute = self?.compute else { return }
            let output = await Task.detached(priority: .userInitiated) {
                compute(request)
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
