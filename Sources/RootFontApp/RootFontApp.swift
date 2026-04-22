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
        WindowGroup(AppMetadata.appName) {
            RootSplitView(viewModel: viewModel)
                .background(
                    WindowAccessor(
                        onResolve: { window in
                            window.minSize = NSSize(width: 900, height: 600)
                            window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
                            window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
                            window.tabbingMode = .disallowed
                        },
                        onAlwaysApply: { window in
                            window.titlebarSeparatorStyle = .none
                            if let toolbar = window.toolbar {
                                toolbar.showsBaselineSeparator = false
                            }
                        }
                    )
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
                Button("About \(AppMetadata.appName)") {
                    showAboutPanel()
                }
            }
        }
    }

    private func showAboutPanel() {
        let aboutView = AboutPanelView(
            appName: AppMetadata.appName,
            versionText: AppMetadata.semanticVersionDisplay,
            slogan: viewModel.tr(.aboutSlogan),
            websiteURL: AppMetadata.websiteURL,
            githubURL: AppMetadata.githubURL,
            websiteLabel: viewModel.tr(.aboutWebsite),
            githubLabel: viewModel.tr(.aboutGitHub),
            copyVersionLabel: viewModel.tr(.aboutCopyVersion),
            versionCopiedLabel: viewModel.tr(.aboutVersionCopied),
            copyrightText: AppMetadata.copyrightText
        )
        let window = RootFontApp.aboutWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About \(AppMetadata.appName)"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: aboutView)
        RootFontApp.aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

private struct AboutPanelView: View {
    let appName: String
    let versionText: String
    let slogan: String
    let websiteURL: String
    let githubURL: String
    let websiteLabel: String
    let githubLabel: String
    let copyVersionLabel: String
    let versionCopiedLabel: String
    let copyrightText: String
    @State private var didCopyVersion = false

    var body: some View {
        VStack(spacing: 14) {
            if let nsImage = NSImage(named: "logo-rootfont-300x300") {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
            }
            Text(appName)
                .font(.title3.weight(.semibold))
            Text(versionText)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(slogan)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                if let url = URL(string: websiteURL) {
                    Link(websiteLabel, destination: url)
                        .font(.caption)
                }
                if let url = URL(string: githubURL) {
                    Link(githubLabel, destination: url)
                        .font(.caption)
                }
                Button(didCopyVersion ? versionCopiedLabel : copyVersionLabel) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(versionText, forType: .string)
                    didCopyVersion = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        didCopyVersion = false
                    }
                }
                .font(.caption)
            }
            Text(copyrightText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
