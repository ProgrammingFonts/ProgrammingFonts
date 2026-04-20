import AppKit
import SwiftUI

@main
struct RootFontApp: App {
    private static var aboutWindow: NSWindow?

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
        let versionDisplay = "\(appVersion)(\(buildNumber))"
        let aboutView = AboutPanelView(versionText: "v\(versionDisplay)")
        let window = RootFontApp.aboutWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About RootFont"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: aboutView)
        RootFontApp.aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct AboutPanelView: View {
    let versionText: String

    var body: some View {
        VStack(spacing: 14) {
            if let nsImage = NSImage(named: "logo-rootfont-300x300") {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
            }
            Text("RootFont")
                .font(.title3.weight(.semibold))
            Text(versionText)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
