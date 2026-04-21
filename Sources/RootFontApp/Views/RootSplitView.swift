import SwiftUI
import UniformTypeIdentifiers

struct RootSplitView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } content: {
            FontListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 560, ideal: 760)
        } detail: {
            FontPreviewView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380)
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
