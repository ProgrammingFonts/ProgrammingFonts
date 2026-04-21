import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var smartCollectionName = ""
    @State private var coverageInput = ""
    @State private var coverageDebounceTask: Task<Void, Never>?

    var body: some View {
        List(selection: Binding(
            get: { viewModel.sidebarFilter },
            set: { viewModel.updateSidebarFilter($0) }
        )) {
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

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(viewModel.tr(.glyphCoverage), systemImage: "character.textbox")
                        .font(.subheadline)
                    TextField(
                        viewModel.tr(.glyphCoveragePlaceholder),
                        text: $coverageInput
                    )
                    .textFieldStyle(.roundedBorder)

                    Text(viewModel.tr(.glyphCoverageDescription))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section(viewModel.tr(.smartCollections)) {
                HStack(spacing: 6) {
                    TextField(viewModel.tr(.smartCollectionNamePlaceholder), text: $smartCollectionName)
                    Button(viewModel.tr(.save)) {
                        viewModel.saveCurrentFiltersAsSmartCollection(named: smartCollectionName)
                        smartCollectionName = ""
                    }
                    .disabled(smartCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(viewModel.smartCollections) { collection in
                    HStack {
                        Button(collection.name) {
                            viewModel.applySmartCollection(collection)
                            coverageInput = collection.glyphCoverageQuery
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 8)
                        Button(role: .destructive) {
                            viewModel.removeSmartCollection(collection)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Keep language control visible in the main UI.
            Section(viewModel.tr(.settings)) {
                VStack(alignment: .leading, spacing: 4) {
                    Picker(viewModel.tr(.language), selection: Binding(
                        get: { viewModel.language },
                        set: { viewModel.updateLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(viewModel.tr(.languageDescription))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Picker(viewModel.tr(.appearance), selection: Binding(
                        get: { viewModel.appearanceMode },
                        set: { viewModel.updateAppearanceMode($0) }
                    )) {
                        Text(viewModel.tr(.appearanceSystem)).tag(AppAppearanceMode.system)
                        Text(viewModel.tr(.appearanceLight)).tag(AppAppearanceMode.light)
                        Text(viewModel.tr(.appearanceDark)).tag(AppAppearanceMode.dark)
                    }
                    .pickerStyle(.menu)

                    Text(viewModel.tr(.appearanceDescription))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(viewModel.tr(.showSystemAliasFonts))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { viewModel.showSystemAliasFonts },
                        set: { viewModel.updateShowSystemAliasFonts($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Text(viewModel.tr(.showSystemAliasFontsDescription))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("RootFont")
        .onAppear {
            coverageInput = viewModel.glyphCoverageQuery
        }
        .onChange(of: coverageInput) { _, newValue in
            coverageDebounceTask?.cancel()
            coverageDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if viewModel.glyphCoverageQuery != newValue {
                        viewModel.updateGlyphCoverageQuery(newValue)
                    }
                }
            }
        }
        .onChange(of: viewModel.glyphCoverageQuery) { _, newValue in
            if coverageInput != newValue {
                coverageInput = newValue
            }
        }
        .onDisappear {
            coverageDebounceTask?.cancel()
        }
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
    }
}
