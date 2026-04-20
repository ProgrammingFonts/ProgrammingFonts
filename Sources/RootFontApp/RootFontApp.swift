import AppKit
import SwiftUI

@main
struct RootFontApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        AppAppearanceApplier.applyImmediately(PreferencesStore().appearanceMode)
    }

    @StateObject private var viewModel = FontBrowserViewModel(
        catalogService: FontCatalogService(),
        preferencesStore: PreferencesStore()
    )

    var body: some Scene {
        WindowGroup("RootFont") {
            RootSplitView(viewModel: viewModel)
                .background(
                    WindowAccessor { window in
                        window.minSize = NSSize(width: 900, height: 600)
                        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
                        window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
                        window.tabbingMode = .disallowed
                    }
                )
                .onAppear {
                    viewModel.load()
                    AppAppearanceApplier.applyImmediately(viewModel.appearanceMode)
                }
                .onChange(of: viewModel.appearanceMode) { _, newValue in
                    AppAppearanceApplier.apply(newValue)
                }
        }
        .commands {
            // This app is single-window and does not need "New" items.
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) { }
            CommandGroup(replacing: .systemServices) { }
            CommandGroup(replacing: .appInfo) {
                Button("About RootFont") {
                    showAboutPanel()
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func showAboutPanel() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "RootFont",
            .version: appVersion,
            .applicationVersion: buildNumber
        ]

        if let icon = NSImage(named: "logo-rootfont-300x300") {
            options[.applicationIcon] = icon
        }

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
