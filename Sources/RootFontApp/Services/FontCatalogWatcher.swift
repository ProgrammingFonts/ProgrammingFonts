import CoreServices
import Foundation

final class FontCatalogWatcher: @unchecked Sendable {
    private final class CallbackBox: @unchecked Sendable {
        let onEvent: @Sendable () -> Void

        init(onEvent: @escaping @Sendable () -> Void) {
            self.onEvent = onEvent
        }
    }

    private let paths: [String]
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "rootfont.fontCatalogWatcher")
    private let queueKey = DispatchSpecificKey<Bool>()
    private var stream: FSEventStreamRef?
    private var callbackPointer: UnsafeMutableRawPointer?
    private var debounceWorkItem: DispatchWorkItem?

    init(urls: [URL], onChange: @escaping @Sendable () -> Void) {
        self.paths = urls.map(\.path)
        self.onChange = onChange
        queue.setSpecific(key: queueKey, value: true)
    }

    func start() {
        withStateQueue { startLocked() }
    }

    func stop() {
        withStateQueue { stopLocked() }
    }

    deinit {
        stop()
    }

    private func startLocked() {
        guard stream == nil, !paths.isEmpty else { return }

        let box = CallbackBox { [weak self] in
            self?.scheduleReloadLocked()
        }
        let pointer = Unmanaged.passRetained(box).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: pointer,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
        )
        let latency: CFTimeInterval = 0.3

        guard let created = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()
                box.onEvent()
            },
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            Unmanaged<CallbackBox>.fromOpaque(pointer).release()
            return
        }

        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            Unmanaged<CallbackBox>.fromOpaque(pointer).release()
            return
        }
        callbackPointer = pointer
        stream = created
    }

    private func stopLocked() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        if let callbackPointer {
            Unmanaged<CallbackBox>.fromOpaque(callbackPointer).release()
            self.callbackPointer = nil
        }
    }

    private func scheduleReloadLocked() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.deliverChangeIfActive()
            }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func deliverChangeIfActive() {
        var active = false
        withStateQueue { active = stream != nil }
        if active {
            onChange()
        }
    }

    private func withStateQueue(_ operation: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) == true {
            operation()
        } else {
            queue.sync(execute: operation)
        }
    }

    static func defaultWatchURLs(fileManager: FileManager = .default) -> [URL] {
        var urls: [URL] = []
        if let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            urls.append(library.appendingPathComponent("Fonts", isDirectory: true))
        }
        return urls
    }
}
