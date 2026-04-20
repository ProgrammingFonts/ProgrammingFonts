import SwiftUI

struct RootSplitView: View {
    @ObservedObject var viewModel: FontBrowserViewModel

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
    }
}
