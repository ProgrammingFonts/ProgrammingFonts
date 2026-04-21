import AppKit
import SwiftUI

struct FontListView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var displayMode: DisplayMode = .grid
    @State private var densityMode: DensityMode = .compact

    enum DisplayMode: String, CaseIterable, Identifiable {
        case grid
        case list

        var id: Self { self }
    }

    enum DensityMode: String, CaseIterable, Identifiable {
        case compact
        case comfortable

        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .opacity(0.35)

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView(viewModel.tr(.loadingFonts))
                        .controlSize(.small)
                    Spacer()
                } else if let errorMessage = viewModel.loadErrorMessage {
                    ContentUnavailableView(
                        viewModel.tr(.loadFailed),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.filteredFonts.isEmpty {
                    ContentUnavailableView(
                        viewModel.tr(.noMatchingFonts),
                        systemImage: "magnifyingglass",
                        description: Text(viewModel.tr(.tryClearFilters))
                    )
                } else {
                    if displayMode == .grid {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: gridMinimumWidth, maximum: gridMaximumWidth), spacing: gridSpacing)],
                                spacing: gridSpacing
                            ) {
                                ForEach(viewModel.filteredFonts) { item in
                                    FontGridCard(
                                        item: item,
                                        isSelected: viewModel.selectedFont?.id == item.id,
                                        isFavorite: viewModel.isFavorite(item),
                                        previewText: viewModel.previewText,
                                        densityMode: densityMode,
                                        language: viewModel.language
                                    ) {
                                        viewModel.selectFont(item)
                                    } onToggleFavorite: {
                                        viewModel.toggleFavorite(item)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 0)
                            .padding(.bottom, 12)
                        }
                    } else {
                        List(viewModel.filteredFonts, selection: Binding(
                            get: { viewModel.selectedFont?.id },
                            set: { selectedID in
                                guard let selectedID,
                                      let item = viewModel.filteredFonts.first(where: { $0.id == selectedID }) else { return }
                                viewModel.selectFont(item)
                            }
                        )) { item in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.familyName).font(.headline)
                                    Text(item.displayName).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(viewModel.styleLabel(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    viewModel.toggleFavorite(item)
                                } label: {
                                    Image(systemName: viewModel.isFavorite(item) ? "star.fill" : "star")
                                        .foregroundStyle(viewModel.isFavorite(item) ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectFont(item)
                            }
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(hSpacing: 10, vSpacing: 10) {
                TextField(viewModel.tr(.searchPlaceholder), text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260, idealWidth: 360, maxWidth: 480)
                    .controlSize(.regular)
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.applyFilters()
                    }

                Picker(viewModel.tr(.source), selection: Binding(
                    get: { viewModel.selectedSource },
                    set: { newValue in
                        viewModel.selectedSource = newValue
                        viewModel.applyFilters()
                    }
                )) {
                    Text(viewModel.tr(.allSources)).tag(FontSource?.none)
                    Text(viewModel.tr(.system)).tag(FontSource?.some(.system))
                    Text(viewModel.tr(.user)).tag(FontSource?.some(.user))
                }
                .controlSize(.regular)
                .frame(minWidth: pickerMinWidth)
                .fixedSize()

                Picker(viewModel.tr(.style), selection: Binding(
                    get: { viewModel.selectedStyle },
                    set: { newValue in
                        viewModel.selectedStyle = newValue
                        viewModel.applyFilters()
                    }
                )) {
                    Text(viewModel.tr(.allStyles)).tag(FontStyleTag?.none)
                    Text(viewModel.tr(.regular)).tag(FontStyleTag?.some(.regular))
                    Text(viewModel.tr(.bold)).tag(FontStyleTag?.some(.bold))
                    Text(viewModel.tr(.italic)).tag(FontStyleTag?.some(.italic))
                }
                .controlSize(.regular)
                .frame(minWidth: pickerMinWidth)
                .fixedSize()

                Picker(viewModel.tr(.sort), selection: Binding(
                    get: { viewModel.sortOption },
                    set: { newValue in
                        viewModel.sortOption = newValue
                        viewModel.applyFilters()
                    }
                )) {
                    ForEach(FontBrowserViewModel.SortOption.allCases) { option in
                        Text(viewModel.title(for: option)).tag(option)
                    }
                }
                .controlSize(.regular)
                .frame(minWidth: sortPickerMinWidth)
                .fixedSize()

                Picker(viewModel.tr(.display), selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode == .grid ? viewModel.tr(.grid) : viewModel.tr(.list)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .frame(width: segmentedDisplayWidth)

                if displayMode == .grid {
                    Picker(viewModel.tr(.density), selection: $densityMode) {
                        ForEach(DensityMode.allCases) { mode in
                            Text(mode == .compact ? viewModel.tr(.compact) : viewModel.tr(.comfortable)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.regular)
                    .frame(width: segmentedDensityWidth)
                }
            }

            FlowLayout(hSpacing: 14, vSpacing: 6) {
                Text("\(viewModel.filteredFonts.count) \(viewModel.tr(.totalFonts))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(viewModel.activeFilterSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Button(viewModel.tr(.jumpAll)) {
                    viewModel.jumpToAllFonts()
                }
                .buttonStyle(.link)
                Button(viewModel.tr(.jumpFavorites)) {
                    viewModel.jumpToFavorites()
                }
                .buttonStyle(.link)
                Button(viewModel.tr(.jumpRecents)) {
                    viewModel.jumpToRecents()
                }
                .buttonStyle(.link)
                Button(viewModel.tr(.clearFilters)) {
                    viewModel.clearAllFilters()
                }
                .buttonStyle(.link)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pickerMinWidth: CGFloat {
        switch viewModel.language {
        case .english: return 150
        case .simplifiedChinese, .traditionalChinese: return 140
        }
    }

    private var sortPickerMinWidth: CGFloat {
        switch viewModel.language {
        case .english: return 180
        case .simplifiedChinese, .traditionalChinese: return 170
        }
    }

    private var segmentedDisplayWidth: CGFloat {
        switch viewModel.language {
        case .english: return 160
        case .simplifiedChinese, .traditionalChinese: return 140
        }
    }

    private var segmentedDensityWidth: CGFloat {
        switch viewModel.language {
        case .english: return 200
        case .simplifiedChinese, .traditionalChinese: return 160
        }
    }

    private var gridMinimumWidth: CGFloat {
        densityMode == .compact ? 170 : 240
    }

    private var gridMaximumWidth: CGFloat {
        densityMode == .compact ? 220 : 300
    }

    private var gridSpacing: CGFloat {
        densityMode == .compact ? 8 : 12
    }
}

private struct FontGridCard: View {
    let item: FontItem
    let isSelected: Bool
    let isFavorite: Bool
    let previewText: String
    let densityMode: FontListView.DensityMode
    let language: AppLanguage
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.familyName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove favorite" : "Add favorite")
            }

            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(sampleText)
                .font(previewFont)
                .lineLimit(densityMode == .compact ? 1 : 2)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                tag(text: item.source == .system ? L10n.tr(.system, language: language) : L10n.tr(.user, language: language))
                Spacer(minLength: 0)
                tag(text: styleLabel)
            }
        }
        .padding(densityMode == .compact ? 10 : 12)
        .frame(maxWidth: .infinity, minHeight: densityMode == .compact ? 112 : 146, alignment: .topLeading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: isSelected ? 1.4 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isHovering ? 1.01 : 1)
        .shadow(color: .black.opacity(isHovering ? 0.12 : 0), radius: isHovering ? 5 : 0, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .onTapGesture(perform: onSelect)
    }

    private func tag(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.14), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.17)
        }
        return Color.secondary.opacity(isHovering ? 0.14 : 0.10)
    }

    private var cardBorder: Color {
        if isSelected {
            return Color.accentColor.opacity(0.82)
        }
        return Color.secondary.opacity(isHovering ? 0.24 : 0.14)
    }

    private var sampleText: String {
        let trimmed = previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "The quick brown fox 你好" : trimmed
    }

    private var previewFont: Font {
        let size: CGFloat = densityMode == .compact ? 16 : 20
        if let font = NSFont(name: item.postScriptName, size: size) {
            return Font(font)
        }
        return .system(size: size)
    }

    private var styleLabel: String {
        if item.styleTags.contains(.bold) { return L10n.tr(.bold, language: language) }
        if item.styleTags.contains(.italic) { return L10n.tr(.italic, language: language) }
        if item.styleTags.contains(.regular) { return L10n.tr(.regular, language: language) }
        return L10n.tr(.other, language: language)
    }
}
