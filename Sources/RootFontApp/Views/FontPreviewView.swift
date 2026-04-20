import AppKit
import SwiftUI

struct FontPreviewView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var previewPreset: FontBrowserViewModel.PreviewPreset = .mixed

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selected = viewModel.selectedFont {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.familyName).font(.title2).bold()
                    Text(selected.displayName).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("\(viewModel.tr(.sourcePrefix))\(viewModel.sourceLabel(for: selected))")
                        Text("\(viewModel.tr(.stylePrefix))\(viewModel.styleLabel(for: selected))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(viewModel.tr(.copyFontName)) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(selected.postScriptName, forType: .string)
                        }
                        .buttonStyle(.link)
                        Text(selected.postScriptName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }

                HStack(spacing: 8) {
                    Text(viewModel.tr(.quickSample))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker(viewModel.tr(.quickSample), selection: $previewPreset) {
                        ForEach(FontBrowserViewModel.PreviewPreset.allCases) { preset in
                            Text(preset.title(language: viewModel.language)).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: previewPreset) { _, newPreset in
                        viewModel.applyPreviewPreset(newPreset)
                    }
                }

                TextField(viewModel.tr(.previewText), text: $viewModel.previewText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.previewText) { _, _ in
                        viewModel.updatePreviewText(viewModel.previewText)
                    }

                VStack(alignment: .leading) {
                    Text("\(viewModel.tr(.previewSize)): \(Int(viewModel.previewSize)) px")
                    Slider(value: $viewModel.previewSize, in: 12...96, step: 1)
                        .onChange(of: viewModel.previewSize) { _, _ in
                            viewModel.updatePreviewSize(viewModel.previewSize)
                        }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        previewBlock(text: viewModel.previewText, size: viewModel.previewSize, item: selected)
                        previewBlock(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", size: max(14, viewModel.previewSize * 0.72), item: selected)
                        previewBlock(text: "abcdefghijklmnopqrstuvwxyz 0123456789", size: max(12, viewModel.previewSize * 0.58), item: selected)
                    }
                }
                if !viewModel.hasRenderablePreviewFont() {
                    Label(viewModel.tr(.fallbackPreviewInfo), systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                    Text(viewModel.tr(.selectFontTitle))
                        .font(.title2.weight(.semibold))
                    Text(viewModel.tr(.selectFontHint))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(viewModel.tr(.selectFontTip))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private func previewBlock(text: String, size: Double, item: FontItem) -> some View {
        Text(text)
            .font(previewFont(for: item, size: size))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary.opacity(0.3))
            .cornerRadius(10)
    }

    private func previewFont(for item: FontItem, size: Double) -> Font {
        if let font = NSFont(name: item.postScriptName, size: size) {
            return Font(font)
        }
        return .system(size: size)
    }
}
