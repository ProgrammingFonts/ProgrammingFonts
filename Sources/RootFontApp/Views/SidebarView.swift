import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: FontBrowserViewModel

    var body: some View {
        List(selection: $viewModel.sidebarFilter) {
            Section(viewModel.tr(.browse)) {
                Label(viewModel.tr(.allFonts), systemImage: "textformat").tag(FontBrowserViewModel.SidebarFilter.all)
                Label(viewModel.tr(.systemFonts), systemImage: "desktopcomputer").tag(FontBrowserViewModel.SidebarFilter.system)
                Label(viewModel.tr(.userFonts), systemImage: "person").tag(FontBrowserViewModel.SidebarFilter.user)
            }

            Section(viewModel.tr(.personal)) {
                Label("\(viewModel.tr(.favorites)) (\(viewModel.favoriteCount))", systemImage: "star")
                    .tag(FontBrowserViewModel.SidebarFilter.favorites)
                Label("\(viewModel.tr(.recents)) (\(viewModel.recentCount))", systemImage: "clock")
                    .tag(FontBrowserViewModel.SidebarFilter.recents)
            }

            // Keep language control visible in the main UI.
            Section(viewModel.tr(.settings)) {
                Picker(viewModel.tr(.language), selection: Binding(
                    get: { viewModel.language },
                    set: { viewModel.updateLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Picker(viewModel.tr(.appearance), selection: Binding(
                    get: { viewModel.appearanceMode },
                    set: { viewModel.updateAppearanceMode($0) }
                )) {
                    Text(viewModel.tr(.appearanceSystem)).tag(AppAppearanceMode.system)
                    Text(viewModel.tr(.appearanceLight)).tag(AppAppearanceMode.light)
                    Text(viewModel.tr(.appearanceDark)).tag(AppAppearanceMode.dark)
                }
                .pickerStyle(.menu)

                Toggle(
                    viewModel.tr(.showSystemAliasFonts),
                    isOn: Binding(
                        get: { viewModel.showSystemAliasFonts },
                        set: { viewModel.updateShowSystemAliasFonts($0) }
                    )
                )
            }
        }
        .navigationTitle("RootFont")
        .toolbar {
            ToolbarItemGroup {
                if viewModel.sidebarFilter == .favorites, viewModel.favoriteCount > 0 {
                    Button(viewModel.tr(.clearFavorites)) {
                        viewModel.clearFavorites()
                    }
                }
                if viewModel.sidebarFilter == .recents, viewModel.recentCount > 0 {
                    Button(viewModel.tr(.clearRecents)) {
                        viewModel.clearRecents()
                    }
                }
            }
        }
        .onChange(of: viewModel.sidebarFilter) { _, _ in
            viewModel.applyFilters()
        }
    }
}
