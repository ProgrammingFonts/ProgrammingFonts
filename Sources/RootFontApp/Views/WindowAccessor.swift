import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void
    var onAlwaysApply: ((NSWindow) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                context.coordinator.resolveIfNeeded(window, onResolve: onResolve)
                onAlwaysApply?(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                context.coordinator.resolveIfNeeded(window, onResolve: onResolve)
                onAlwaysApply?(window)
            }
        }
    }

    @MainActor
    final class Coordinator {
        private var configuredWindows = Set<ObjectIdentifier>()
        private var observers: [ObjectIdentifier: NSObjectProtocol] = [:]

        func resolveIfNeeded(_ window: NSWindow, onResolve: (NSWindow) -> Void) {
            let identifier = ObjectIdentifier(window)
            guard !configuredWindows.contains(identifier) else { return }
            configuredWindows.insert(identifier)
            onResolve(window)

            let observer = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.discard(identifier: identifier)
                }
            }
            observers[identifier] = observer
        }

        private func discard(identifier: ObjectIdentifier) {
            configuredWindows.remove(identifier)
            if let observer = observers.removeValue(forKey: identifier) {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
