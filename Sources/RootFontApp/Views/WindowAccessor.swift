import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    private static var configuredWindows = Set<ObjectIdentifier>()

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                resolveIfNeeded(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                resolveIfNeeded(window)
            }
        }
    }

    private func resolveIfNeeded(_ window: NSWindow) {
        let identifier = ObjectIdentifier(window)
        guard !Self.configuredWindows.contains(identifier) else { return }
        Self.configuredWindows.insert(identifier)
        onResolve(window)
    }
}
