import AppKit
import SwiftUI

struct FontListView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var displayMode: DisplayMode = .grid
    @State private var densityMode: DensityMode = .compact
    @State private var listPreviewSize: Double = 18
    @State private var searchInput: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var didAutofocusSearch = false
    @State private var cachedGridColumnCount: Int = 4
    @State private var lastGridContainerWidth: CGFloat = 0

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
                        GeometryReader { proxy in
                            ScrollView {
                                LazyVGrid(
                                    columns: cachedGridColumns,
                                    spacing: gridSpacing
                                ) {
                                    ForEach(viewModel.filteredFonts) { item in
                                        let display = viewModel.preferredSearchDisplay(for: item)
                                        FontGridCard(
                                            item: item,
                                            primaryTitle: display.primary,
                                            secondaryTitle: display.secondary,
                                            isSelected: viewModel.selectedFont?.id == item.id,
                                            isFavorite: viewModel.isFavorite(item),
                                            previewText: viewModel.previewText,
                                            previewSize: listPreviewSize,
                                            densityMode: densityMode,
                                            language: viewModel.language,
                                            searchQuery: viewModel.searchQuery
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
                            .onChange(of: proxy.size.width, initial: true) { _, newWidth in
                                lastGridContainerWidth = newWidth
                                updateGridColumnCountIfNeeded(for: newWidth)
                            }
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
                            let display = viewModel.preferredSearchDisplay(for: item)
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text.highlighted(
                                        display.primary,
                                        query: viewModel.searchQuery
                                    ).font(.system(size: listPreviewSize, weight: .semibold))
                                    Text.highlighted(
                                        display.secondary,
                                        query: viewModel.searchQuery
                                    ).font(.system(size: max(11, listPreviewSize - 2))).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(viewModel.styleLabel(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if item.programming?.isMonospaced == true,
                                   let score = item.programmingScore {
                                    scoreChip(grade: score.grade, language: viewModel.language)
                                }
                                Button {
                                    viewModel.toggleFavorite(item)
                                } label: {
                                    Image(systemName: viewModel.isFavorite(item) ? "star.fill" : "star")
                                        .foregroundStyle(viewModel.isFavorite(item) ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help(viewModel.tr(viewModel.isFavorite(item) ? .favoriteRemove : .favoriteAdd))
                                .accessibilityLabel(viewModel.tr(viewModel.isFavorite(item) ? .favoriteRemove : .favoriteAdd))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .listStyle(.inset)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            displayMode = DisplayMode(rawValue: UserDefaults.standard.string(forKey: "rootfont.displayMode") ?? "grid") ?? .grid
            densityMode = DensityMode(rawValue: UserDefaults.standard.string(forKey: "rootfont.densityMode") ?? "compact") ?? .compact
            let savedPreviewSize = UserDefaults.standard.double(forKey: "rootfont.listPreviewSize")
            listPreviewSize = savedPreviewSize == 0 ? 18 : savedPreviewSize
            searchInput = viewModel.searchQuery
            if !didAutofocusSearch {
                didAutofocusSearch = true
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
        .onChange(of: displayMode) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "rootfont.displayMode")
        }
        .onChange(of: densityMode) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "rootfont.densityMode")
            updateGridColumnCountIfNeeded(for: lastGridContainerWidth)
        }
        .onChange(of: listPreviewSize) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "rootfont.listPreviewSize")
            updateGridColumnCountIfNeeded(for: lastGridContainerWidth)
        }
        .onChange(of: searchInput) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if viewModel.searchQuery != newValue {
                        viewModel.updateSearchQuery(newValue)
                    }
                }
            }
        }
        .onChange(of: viewModel.searchQuery) { _, newValue in
            if searchInput != newValue {
                searchInput = newValue
            }
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(hSpacing: 10, vSpacing: 10) {
                TextField(viewModel.tr(.searchPlaceholder), text: Binding(
                    get: { searchInput },
                    set: { searchInput = $0 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 260, idealWidth: 360, maxWidth: 480)
                    .controlSize(.regular)
                    .focused($isSearchFieldFocused)

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
                    Text(viewModel.tr(.monospace)).tag(FontStyleTag?.some(.monospace))
                }
                .controlSize(.regular)
                .frame(minWidth: pickerMinWidth)
                .fixedSize()

                Picker(viewModel.tr(.sort), selection: Binding(
                    get: { viewModel.sortOption },
                    set: { newValue in
                        viewModel.updateSortOption(newValue)
                    }
                )) {
                    ForEach(FontBrowserViewModel.SortOption.allCases) { option in
                        Text(viewModel.title(for: option)).tag(option)
                    }
                }
                .controlSize(.regular)
                .frame(minWidth: sortPickerMinWidth)
                .fixedSize()

                HStack(spacing: 6) {
                    Text(viewModel.tr(.display))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Picker("", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode == .grid ? viewModel.tr(.grid) : viewModel.tr(.list)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.regular)
                    .frame(width: segmentedDisplayWidth)
                }
                .fixedSize()

                if displayMode == .grid {
                    HStack(spacing: 6) {
                        Text(viewModel.tr(.density))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                        Picker("", selection: $densityMode) {
                            ForEach(DensityMode.allCases) { mode in
                                Text(mode == .compact ? viewModel.tr(.compact) : viewModel.tr(.comfortable)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .controlSize(.regular)
                        .frame(width: segmentedDensityWidth)
                    }
                    .fixedSize()
                }

                HStack(spacing: 6) {
                    Text(viewModel.tr(.listPreviewSize))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Slider(
                        value: Binding(
                            get: { listPreviewSize },
                            set: { listPreviewSize = $0.rounded() }
                        ),
                        in: 2...500
                    )
                        .frame(width: sliderWidth)
                    Text("\(Int(listPreviewSize))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 24, alignment: .trailing)
                }
                .fixedSize()
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
        case .japanese: return 150
        case .korean: return 155
        }
    }

    private var sortPickerMinWidth: CGFloat {
        switch viewModel.language {
        case .english: return 180
        case .simplifiedChinese, .traditionalChinese: return 170
        case .japanese: return 190
        case .korean: return 195
        }
    }

    private var segmentedDisplayWidth: CGFloat {
        switch viewModel.language {
        case .english: return 160
        case .simplifiedChinese, .traditionalChinese: return 140
        case .japanese: return 150
        case .korean: return 150
        }
    }

    private var segmentedDensityWidth: CGFloat {
        switch viewModel.language {
        case .english: return 200
        case .simplifiedChinese, .traditionalChinese: return 160
        case .japanese: return 190
        case .korean: return 190
        }
    }

    private var sliderWidth: CGFloat {
        switch viewModel.language {
        case .english: return 130
        case .simplifiedChinese, .traditionalChinese: return 110
        case .japanese: return 120
        case .korean: return 125
        }
    }

    private var gridSpacing: CGFloat {
        densityMode == .compact ? 8 : 12
    }

    private var cachedGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing),
            count: cachedGridColumnCount
        )
    }

    private func updateGridColumnCountIfNeeded(for containerWidth: CGFloat) {
        guard containerWidth > 0 else { return }
        let newCount = computeGridColumnCount(for: containerWidth)
        if newCount != cachedGridColumnCount {
            cachedGridColumnCount = newCount
        }
    }

    private func computeGridColumnCount(for containerWidth: CGFloat) -> Int {
        let horizontalPadding: CGFloat = 32
        let available = max(containerWidth - horizontalPadding, 200)

        if listPreviewSize >= 499.5 { return 2 }

        let sizeRatio = min(max((listPreviewSize - 2) / (500 - 2), 0), 1)
        let minCardWidth: CGFloat = densityMode == .compact ? 100 : 140
        let maxCardWidth: CGFloat = max(minCardWidth + 1, available / 2)
        let targetCardWidth = minCardWidth + (maxCardWidth - minCardWidth) * sizeRatio
        let raw = (available + gridSpacing) / (targetCardWidth + gridSpacing)
        return max(2, Int(floor(raw)))
    }
}

private struct FontGridCard: View {
    let item: FontItem
    let primaryTitle: String
    let secondaryTitle: String
    let isSelected: Bool
    let isFavorite: Bool
    let previewText: String
    let previewSize: Double
    let densityMode: FontListView.DensityMode
    let language: AppLanguage
    let searchQuery: String
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text.highlighted(primaryTitle, query: searchQuery)
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
                .help(L10n.tr(isFavorite ? .favoriteRemove : .favoriteAdd, language: language))
                .accessibilityLabel(L10n.tr(isFavorite ? .favoriteRemove : .favoriteAdd, language: language))
            }

            Text.highlighted(secondaryTitle, query: searchQuery)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(sampleText)
                .font(previewFont)
                .lineLimit(densityMode == .compact ? 1 : 2)
                .minimumScaleFactor(0.25)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: sampleTextVisibleHeight, alignment: .top)
                .clipped()

            HStack(spacing: 6) {
                tag(text: item.source == .system ? L10n.tr(.system, language: language) : L10n.tr(.user, language: language))
                if item.programming?.isMonospaced == true,
                   let score = item.programmingScore {
                    scoreChip(grade: score.grade)
                }
                Spacer(minLength: 0)
                tag(text: styleLabel)
            }
        }
        .padding(densityMode == .compact ? 10 : 12)
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
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

    private func scoreChip(grade: ProgrammingGrade) -> some View {
        Text(gradeText(grade))
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(gradeColor(grade).opacity(0.18), in: Capsule())
            .foregroundStyle(gradeColor(grade))
            .accessibilityLabel(L10n.tr(gradeL10nKey(grade), language: language))
    }

    private func gradeText(_ grade: ProgrammingGrade) -> String {
        switch grade {
        case .s: return "S"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .notRecommended: return "NR"
        }
    }

    private func gradeColor(_ grade: ProgrammingGrade) -> Color {
        switch grade {
        case .s: return .green
        case .a: return .mint
        case .b: return .yellow
        case .c: return .orange
        case .notRecommended: return .red
        }
    }

    private func gradeL10nKey(_ grade: ProgrammingGrade) -> L10nKey {
        switch grade {
        case .s: return .gradeS
        case .a: return .gradeA
        case .b: return .gradeB
        case .c: return .gradeC
        case .notRecommended: return .gradeNotRecommended
        }
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
        let size = densityMode == .compact ? CGFloat(previewSize) : CGFloat(previewSize + 4)
        if let font = NSFont(name: item.postScriptName, size: size) {
            return Font(font)
        }
        return .system(size: size)
    }

    private var cardMinHeight: CGFloat {
        let base: CGFloat = densityMode == .compact ? 112 : 146
        let chromeHeight: CGFloat = densityMode == .compact ? 84 : 110
        return max(base, sampleTextVisibleHeight + chromeHeight)
    }

    private var sampleTextVisibleHeight: CGFloat {
        let nominal = densityMode == .compact ? CGFloat(previewSize) : CGFloat(previewSize + 4)
        let capFactor: CGFloat = densityMode == .compact ? 0.82 : 1.65
        return nominal * capFactor
    }

    private var styleLabel: String {
        if item.styleTags.contains(.bold) { return L10n.tr(.bold, language: language) }
        if item.styleTags.contains(.italic) { return L10n.tr(.italic, language: language) }
        if item.styleTags.contains(.regular) { return L10n.tr(.regular, language: language) }
        return L10n.tr(.other, language: language)
    }
}

private func scoreChip(grade: ProgrammingGrade, language: AppLanguage) -> some View {
    Text(gradeText(grade))
    .font(.caption2.weight(.bold))
    .lineLimit(1)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background({
        switch grade {
        case .s: return Color.green.opacity(0.18)
        case .a: return Color.mint.opacity(0.18)
        case .b: return Color.yellow.opacity(0.18)
        case .c: return Color.orange.opacity(0.18)
        case .notRecommended: return Color.red.opacity(0.18)
        }
    }(), in: Capsule())
    .foregroundStyle({
        switch grade {
        case .s: return Color.green
        case .a: return Color.mint
        case .b: return Color.yellow
        case .c: return Color.orange
        case .notRecommended: return Color.red
        }
    }())
    .accessibilityLabel(L10n.tr(gradeL10nKey(grade), language: language))
}

private func gradeText(_ grade: ProgrammingGrade) -> String {
    switch grade {
    case .s: return "S"
    case .a: return "A"
    case .b: return "B"
    case .c: return "C"
    case .notRecommended: return "NR"
    }
}

private func gradeL10nKey(_ grade: ProgrammingGrade) -> L10nKey {
    switch grade {
    case .s: return .gradeS
    case .a: return .gradeA
    case .b: return .gradeB
    case .c: return .gradeC
    case .notRecommended: return .gradeNotRecommended
    }
}
