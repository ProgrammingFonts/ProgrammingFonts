import AppKit
import SwiftUI

struct FontPreviewHeaderSection: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    let selected: FontItem
    let activationService: FontActivationServiceProtocol
    @Binding var showCopyToast: Bool
    @Binding var fontBookMessage: String?
    @Binding var fontBookPathHint: String?
    @Binding var activationMessage: String?
    @Binding var activationConflictPath: String?
    @Binding var showInstallConfirm: Bool
    let editorTitle: (EditorTarget) -> String
    let editorCategoryTitle: (EditorTargetCategory) -> String
    let onCopyEditorConfig: (EditorTarget, String) -> Void
    let onExportSpecimenPNG: () -> Void
    let onExportSpecimenPDF: () -> Void
    let onOpenInFontBook: (FontItem) -> Void
    let onPerformActivation: (@escaping () throws -> Void) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selected.familyName(for: viewModel.language))
                .font(.title2).bold()
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(selected.displayName(for: viewModel.language))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            FlowLayout(hSpacing: 10, vSpacing: 4) {
                Text("\(viewModel.tr(.sourcePrefix))\(viewModel.sourceLabel(for: selected))")
                    .lineLimit(1)
                Text("\(viewModel.tr(.stylePrefix))\(viewModel.styleLabel(for: selected))")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(viewModel.tr(.copyFontName)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selected.postScriptName, forType: .string)
                }
                .buttonStyle(.link)
                .fixedSize()
                .accessibilityLabel(viewModel.tr(.copyFontName))
                Menu(viewModel.tr(.copyEditorConfig)) {
                    ForEach(EditorTarget.grouped, id: \.0) { category, targets in
                        Section(editorCategoryTitle(category)) {
                            ForEach(targets) { target in
                                Button(editorTitle(target)) {
                                    onCopyEditorConfig(target, selected.postScriptName)
                                }
                            }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(viewModel.tr(.copyEditorConfig))
                Menu(viewModel.tr(.exportSpecimen)) {
                    Button(viewModel.tr(.exportSpecimen)) {
                        onExportSpecimenPNG()
                    }
                    Button(viewModel.tr(.exportSpecimenPDF)) {
                        onExportSpecimenPDF()
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(viewModel.tr(.exportSpecimen))
                Text(selected.postScriptName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(viewModel.tr(.openInFontBook)) {
                    onOpenInFontBook(selected)
                }
                .buttonStyle(.link)
                .fixedSize()
                .accessibilityLabel(viewModel.tr(.openInFontBook))
            }
            if showCopyToast {
                Text(viewModel.tr(.copiedToClipboard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            if let fontBookMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fontBookMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let fontBookPathHint {
                        Text("\(viewModel.tr(.fontPathPrefix)): \(fontBookPathHint)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            if selected.source == .user {
                HStack(spacing: 8) {
                    Button(viewModel.tr(.activateForSession)) {
                        onPerformActivation {
                            try activationService.activateForProcess(fontID: selected.postScriptName)
                        }
                    }
                    .controlSize(.small)
                    .accessibilityLabel(viewModel.tr(.activateForSession))
                    Button(viewModel.tr(.installForAllApps)) {
                        showInstallConfirm = true
                    }
                    .controlSize(.small)
                    .accessibilityLabel(viewModel.tr(.installForAllApps))
                    if activationService.isManaged(fontID: selected.postScriptName) {
                        Button(viewModel.tr(.uninstallManagedFont)) {
                            onPerformActivation {
                                try activationService.uninstall(fontID: selected.postScriptName)
                            }
                        }
                        .controlSize(.small)
                        .accessibilityLabel(viewModel.tr(.uninstallManagedFont))
                    }
                }
                if let activationMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activationMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let activationConflictPath {
                            Text("\(viewModel.tr(.activationConflictPrefix)): \(activationConflictPath)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Button(viewModel.tr(.openManagedFontsFolder)) {
                    NSWorkspace.shared.open(activationService.managedFontsDirectoryURL())
                }
                .controlSize(.small)
                .accessibilityLabel(viewModel.tr(.openManagedFontsFolder))
            }
        }
    }
}
