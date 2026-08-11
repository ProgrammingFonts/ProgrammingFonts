import AppKit
import SwiftUI
import os

@main
struct RootFontApp: App {
    private static var aboutWindow: NSWindow?
    private let activationService: FontActivationService
    @StateObject private var viewModel: FontBrowserViewModel

    init() {
        let preferences = PreferencesStore()
        let activation = FontActivationService()
        let browserViewModel = FontBrowserViewModel(
            catalogService: FontCatalogService(),
            preferencesStore: preferences,
            activationService: activation
        )
        self.activationService = activation
        _viewModel = StateObject(wrappedValue: browserViewModel)
        NSApplication.shared.setActivationPolicy(.regular)
        // Modern macOS discourages stealing focus on launch; the app will
        // activate naturally when the user opens it. We only set the
        // activation policy here.
        AppAppearanceApplier.applyImmediately(preferences.appearanceMode)
        do {
            try activation.reconcile()
        } catch {
            AppLog.activation.error("startup reconcile failed: \(String(describing: error), privacy: .public)")
            browserViewModel.reportActivationReconcileFailure()
        }
    }

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
                    viewModel.startCatalogWatcherIfNeeded()
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
            CommandMenu(viewModel.tr(.personal)) {
                Button(viewModel.tr(.focusSearch)) {
                    viewModel.focusSearchField()
                }
                .keyboardShortcut("f", modifiers: [.command])
                Button(viewModel.tr(.favoriteAdd)) {
                    if let selected = viewModel.selectedFont {
                        viewModel.toggleFavorite(selected)
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(viewModel.selectedFont == nil)
                Button(viewModel.tr(.jumpFavorites)) {
                    viewModel.jumpToFavorites()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                Button(viewModel.tr(.jumpRecents)) {
                    viewModel.jumpToRecents()
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                Button(viewModel.tr(.jumpAll)) {
                    viewModel.jumpToAllFonts()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                Divider()
                Button(viewModel.tr(.selectPreviousFont)) {
                    viewModel.selectAdjacentFont(offset: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                .disabled(viewModel.filteredFonts.isEmpty)
                Button(viewModel.tr(.selectNextFont)) {
                    viewModel.selectAdjacentFont(offset: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                .disabled(viewModel.filteredFonts.isEmpty)
            }
            CommandGroup(replacing: .appInfo) {
                Button(String(format: viewModel.tr(.aboutTitle), AppMetadata.appName)) {
                    showAboutPanel()
                }
            }
        }
    }

    private func showAboutPanel() {
        let managedCount = activationService.managedCount()
        let systemInfoLine = AppMetadata.systemInfoLine(
            appearance: viewModel.appearanceMode,
            language: viewModel.language,
            managedCount: managedCount
        )
        let aboutView = AboutPanelView(
            appName: AppMetadata.appName,
            versionText: AppMetadata.semanticVersionDisplay,
            buildText: AppMetadata.buildDisplay,
            commitShortSHA: AppMetadata.commitShortSHA,
            diagnosticsLine: AppMetadata.diagnosticsLine(managedCount: managedCount),
            systemInfoLine: systemInfoLine,
            slogan: viewModel.tr(.aboutSlogan),
            websiteURL: AppMetadata.websiteURL,
            githubURL: AppMetadata.githubURL,
            websiteLabel: viewModel.tr(.aboutWebsite),
            githubLabel: viewModel.tr(.aboutGitHub),
            copyVersionLabel: viewModel.tr(.aboutCopyVersion),
            versionCopiedLabel: viewModel.tr(.aboutVersionCopied),
            copySystemInfoLabel: viewModel.tr(.aboutCopySystemInfo),
            systemInfoCopiedLabel: viewModel.tr(.aboutSystemInfoCopied),
            copyrightText: AppMetadata.copyrightText
        )
        let window = RootFontApp.aboutWindow ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(format: viewModel.tr(.aboutTitle), AppMetadata.appName)
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
    let buildText: String
    let commitShortSHA: String
    let diagnosticsLine: String
    let systemInfoLine: String
    let slogan: String
    let websiteURL: String
    let githubURL: String
    let websiteLabel: String
    let githubLabel: String
    let copyVersionLabel: String
    let versionCopiedLabel: String
    let copySystemInfoLabel: String
    let systemInfoCopiedLabel: String
    let copyrightText: String
    @State private var didCopyVersion = false
    @State private var didCopySystemInfo = false
    @State private var copyVersionResetTask: Task<Void, Never>?
    @State private var copySystemInfoResetTask: Task<Void, Never>?
    private let logoFileName = "logo-rootfont-300x300"
    private let logoFileExtension = "png"

    var body: some View {
        VStack(spacing: 14) {
            if let nsImage = aboutLogoImage {
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
            Text(buildText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !commitShortSHA.isEmpty {
                Text("commit \(commitShortSHA)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
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
                    copyToPasteboard(diagnosticsLine)
                    didCopyVersion = true
                    copyVersionResetTask?.cancel()
                    copyVersionResetTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        if !Task.isCancelled { didCopyVersion = false }
                    }
                }
                .font(.caption)
                .help(diagnosticsLine)
                Button(didCopySystemInfo ? systemInfoCopiedLabel : copySystemInfoLabel) {
                    copyToPasteboard("\(diagnosticsLine)\n\(systemInfoLine)")
                    didCopySystemInfo = true
                    copySystemInfoResetTask?.cancel()
                    copySystemInfoResetTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        if !Task.isCancelled { didCopySystemInfo = false }
                    }
                }
                .font(.caption)
                .help(systemInfoLine)
            }
            Text(copyrightText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var aboutLogoImage: NSImage? {
        if let resourceURL = Bundle.module.url(forResource: logoFileName, withExtension: logoFileExtension) {
            if let image = NSImage(contentsOf: resourceURL) {
                return image
            }
        }
        return nil
    }
}
