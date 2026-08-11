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
    private var watcher: FontCatalogWatcher?
    private var pendingReload = false
    private var reloadAction: (() -> Void)?

    var isLoading: Bool { loadTask != nil }

    func managedFontIDs(using service: FontActivationServiceProtocol) -> Set<String> {
        service.managedFontIDs()
    }

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
            self.drainPendingReload()
        }
    }

    func startWatcher(urls: [URL], reload: @escaping () -> Void) {
        guard watcher == nil else { return }
        setReloadHandler(reload)
        watcher = FontCatalogWatcher(urls: urls) { [weak self] in
            Task { @MainActor in self?.handleCatalogChange() }
        }
        watcher?.start()
    }

    func setReloadHandler(_ reload: @escaping () -> Void) {
        reloadAction = reload
    }

    func stopWatcher() {
        watcher?.stop()
        watcher = nil
        reloadAction = nil
        pendingReload = false
    }

    func handleCatalogChange() {
        guard let reloadAction else { return }
        if isLoading {
            pendingReload = true
        } else {
            reloadAction()
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

    private func drainPendingReload() {
        guard pendingReload, let reloadAction else { return }
        pendingReload = false
        reloadAction()
    }
}
