import Foundation
import os

struct FontCatalogLoadOutcome: Sendable {
    let fonts: [FontItem]?
    let failed: Bool
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

        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let stream = service.loadFonts()
            for await event in stream {
                guard !Task.isCancelled, expectedGeneration == self.generation else { return }
                switch event {
                case .partial(let fonts):
                    self.onPartial?(fonts)
                case .progress(let value):
                    self.onProgress?(value)
                case .completed(let fonts):
                    self.loadTask = nil
                    self.onPartial = nil
                    self.onProgress = nil
                    AppLog.catalog.info("catalog loaded: \(fonts.count, privacy: .public) font(s)")
                    completion(FontCatalogLoadOutcome(fonts: fonts, failed: false))
                    self.drainPendingReload()
                    return
                case .failed:
                    self.loadTask = nil
                    self.onPartial = nil
                    self.onProgress = nil
                    AppLog.catalog.error("catalog load failed")
                    completion(FontCatalogLoadOutcome(fonts: nil, failed: true))
                    self.drainPendingReload()
                    return
                }
            }
            // Stream finished without a terminal event — treat as failure.
            guard !Task.isCancelled, expectedGeneration == self.generation else { return }
            self.loadTask = nil
            self.onPartial = nil
            self.onProgress = nil
            AppLog.catalog.error("catalog stream ended without terminal event")
            completion(FontCatalogLoadOutcome(fonts: nil, failed: true))
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

    private func drainPendingReload() {
        guard pendingReload, let reloadAction else { return }
        pendingReload = false
        reloadAction()
    }
}
