import AppKit
import SwiftUI

struct FontPreviewView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var previewPreset: FontBrowserViewModel.PreviewPreset = .mixed
    @State private var useSingleLinePreview = false
    @State private var useMonospacedDigits = false
    @State private var expandedLetterSpacing = false

    var body: some View {
        Group {
            if let selected = viewModel.selectedFont {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(for: selected)
                        quickSampleSection
                        previewTextField
                        previewSizeSection
                        previewModeSection
                        typographyOptionsSection
                        previewBlocksSection(for: selected)
                        if !viewModel.hasRenderablePreviewFont() {
                            Label(viewModel.tr(.fallbackPreviewInfo), systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else if viewModel.hasPartialGlyphFallback(for: viewModel.previewText) {
                            Label(viewModel.tr(.fallbackPartialGlyphInfo), systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text(viewModel.tr(.selectFontTitle))
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(viewModel.tr(.selectFontHint))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(viewModel.tr(.selectFontTip))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func headerSection(for selected: FontItem) -> some View {
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
                Text(selected.postScriptName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var quickSampleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.tr(.quickSample))
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                Picker(viewModel.tr(.quickSample), selection: $previewPreset) {
                    ForEach(FontBrowserViewModel.PreviewPreset.allCases) { preset in
                        Text(preset.title(language: viewModel.language)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Picker(viewModel.tr(.quickSample), selection: $previewPreset) {
                    ForEach(FontBrowserViewModel.PreviewPreset.allCases) { preset in
                        Text(preset.title(language: viewModel.language)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: previewPreset) { _, newPreset in
                viewModel.applyPreviewPreset(newPreset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewTextField: some View {
        TextField(viewModel.tr(.previewText), text: $viewModel.previewText, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
            .onChange(of: viewModel.previewText) { _, _ in
                viewModel.updatePreviewText(viewModel.previewText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(viewModel.tr(.previewSize)): \(Int(viewModel.previewSize)) px")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { viewModel.previewSize },
                    set: { viewModel.previewSize = $0.rounded() }
                ),
                in: 12...96
            )
                .onChange(of: viewModel.previewSize) { _, _ in
                    viewModel.updatePreviewSize(viewModel.previewSize)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewModeSection: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $useSingleLinePreview) {
                Text(viewModel.tr(.previewWrapMode))
            }
            .toggleStyle(.switch)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var typographyOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(viewModel.tr(.previewMonospacedNumeralsStyle), isOn: $useMonospacedDigits)
                .toggleStyle(.switch)
            Toggle(viewModel.tr(.previewExpandedLetterSpacing), isOn: $expandedLetterSpacing)
                .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func previewBlocksSection(for selected: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            previewBlock(text: viewModel.previewText, size: viewModel.previewSize, item: selected)
            previewBlock(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", size: max(14, viewModel.previewSize * 0.72), item: selected)
            previewBlock(text: "abcdefghijklmnopqrstuvwxyz 0123456789", size: max(12, viewModel.previewSize * 0.58), item: selected)
        }
    }

    @ViewBuilder
    private func previewBlock(text: String, size: Double, item: FontItem) -> some View {
        if useSingleLinePreview {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                    .tracking(expandedLetterSpacing ? 0.5 : 0)
                    .lineLimit(1)
                    .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3))
            .cornerRadius(10)
        } else {
            Text(softWrappedText(text))
                .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                .tracking(expandedLetterSpacing ? 0.5 : 0)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary.opacity(0.3))
                .cornerRadius(10)
        }
    }

    private func softWrappedText(_ text: String) -> String {
        text.map { String($0) }.joined(separator: "\u{200B}")
    }

    private func previewFont(for item: FontItem, size: Double, monospacedNumerals: Bool) -> Font {
        if monospacedNumerals {
            return .system(size: size, design: .monospaced)
        }
        if let font = NSFont(name: item.postScriptName, size: size) {
            return Font(font)
        }
        return .system(size: size)
    }
}
