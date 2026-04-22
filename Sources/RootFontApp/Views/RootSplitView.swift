import SwiftUI
import UniformTypeIdentifiers

struct RootSplitView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var isDropTargeted = false
    @State private var isPreviewInspectorPresented = true
    @State private var previewInspectorWidth: CGFloat = 380
    @State private var autoCloseArmed = false
    @State private var autoCloseArmTask: Task<Void, Never>?

    private let previewInspectorIdealWidth: CGFloat = 380
    private let previewInspectorMinWidth: CGFloat = 80
    private let previewInspectorMaxWidth: CGFloat = 640
    private let previewInspectorCloseThreshold: CGFloat = 180
    private let autoCloseArmDelayNanos: UInt64 = 800_000_000

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            FontListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 560, ideal: 760)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isPreviewInspectorPresented.toggle()
                            }
                        } label: {
                            Image(systemName: isPreviewInspectorPresented ? "sidebar.right" : "sidebar.squares.right")
                        }
                        .help(viewModel.tr(isPreviewInspectorPresented ? .collapsePreview : .expandPreview))
                    }
                }
                .inspector(isPresented: $isPreviewInspectorPresented) {
                    FontPreviewView(viewModel: viewModel)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onChange(of: proxy.size.width, initial: true) { _, newWidth in
                                        previewInspectorWidth = newWidth
                                    }
                            }
                        )
                        .inspectorColumnWidth(
                            min: previewInspectorMinWidth,
                            ideal: previewInspectorIdealWidth,
                            max: previewInspectorMaxWidth
                        )
                }
        }
        .overlay(alignment: .bottomTrailing) {
            if isDropTargeted {
                Label(viewModel.tr(.dropFontsToImport), systemImage: "tray.and.arrow.down")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
            }
        }
        .onChange(of: isPreviewInspectorPresented, initial: true) { _, newValue in
            autoCloseArmed = false
            autoCloseArmTask?.cancel()
            guard newValue else { return }
            autoCloseArmTask = Task {
                try? await Task.sleep(nanoseconds: autoCloseArmDelayNanos)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    autoCloseArmed = true
                }
            }
        }
        .onChange(of: previewInspectorWidth) { oldWidth, newWidth in
            guard isPreviewInspectorPresented, autoCloseArmed else { return }
            guard oldWidth > previewInspectorCloseThreshold,
                  newWidth <= previewInspectorCloseThreshold else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isPreviewInspectorPresented = false
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let ext = ["ttf", "otf", "ttc", "otc"]
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                } else {
                    url = nil
                }
                guard let url else { return }
                let allowed = ext.contains(url.pathExtension.lowercased())
                if allowed {
                    Task { @MainActor in
                        _ = viewModel.importFonts(from: [url])
                    }
                }
            }
        }
        return true
    }
}
