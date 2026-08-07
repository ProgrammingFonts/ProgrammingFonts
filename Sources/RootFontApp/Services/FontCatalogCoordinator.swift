import Foundation

private final class FontCatalogCallbackBridge: @unchecked Sendable {
    weak var coordinator: FontCatalogCoordinator?

    @MainActor
    func partial(_ fonts: [FontItem]) {
        coordinator?.deliverPartial(fonts)
    }

    @MainActor
    func progress(_ value: Double) {
        coordinator?.deliverProgress(value)
    }
}

@MainActor
final class FontCatalogCoordinator {
    private var loadTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var onPartial: (([FontItem]) -> Void)?
    private var onProgress: ((Double) -> Void)?

    var isLoading: Bool { loadTask != nil }

    func load(
        service: FontCatalogServiceProtocol,
        onPartial: @escaping ([FontItem]) -> Void,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (FontCatalogLoadOutcome) -> Void
    ) {
        guard loadTask == nil else { return }
        generation &+= 1
        let expectedGeneration = generation
        self.onPartial = onPartial
        self.onProgress = onProgress

        let bridge = FontCatalogCallbackBridge()
        bridge.coordinator = self
        loadTask = Task { @MainActor [weak self] in
            let outcome = await FontCatalogLoadExecutor.execute(
                service: service,
                onPartial: { fonts in
                    Task { @MainActor in bridge.partial(fonts) }
                },
                reportProgress: { progress in
                    Task { @MainActor in bridge.progress(progress) }
                }
            )
            guard let self,
                  !Task.isCancelled,
                  expectedGeneration == self.generation else { return }
            self.loadTask = nil
            self.onPartial = nil
            self.onProgress = nil
            completion(outcome)
        }
    }

    func cancel() {
        generation &+= 1
        loadTask?.cancel()
        loadTask = nil
        onPartial = nil
        onProgress = nil
    }

    fileprivate func deliverPartial(_ fonts: [FontItem]) {
        onPartial?(fonts)
    }

    fileprivate func deliverProgress(_ progress: Double) {
        onProgress?(progress)
    }
}
