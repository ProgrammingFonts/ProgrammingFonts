import AppKit

@MainActor
enum AppAppearanceApplier {
    static func applyImmediately(_ mode: AppAppearanceMode) {
        let appearance = mode.nsAppearance
        NSApplication.shared.appearance = appearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
        }
    }

    static func apply(_ mode: AppAppearanceMode) {
        let appearance = mode.nsAppearance
        NSApplication.shared.appearance = appearance
        for window in NSApplication.shared.windows {
            window.appearance = appearance
            window.invalidateShadow()
            window.viewsNeedDisplay = true
            window.displayIfNeeded()
        }
    }
}
