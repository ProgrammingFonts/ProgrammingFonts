import AppKit
import SwiftUI

struct FontListView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var displayMode: DisplayMode = .grid
    @State private var densityMode: DensityMode = .compact
    @State private var listPreviewSize: Double = 18
    @State private var listPreviewSizeSlider: Double = 18
    @State private var listPreviewSizeDebounceTask: Task<Void, Never>?
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

            if let banner = viewModel.importBannerMessage {
                FontImportBanner(message: banner, onDismiss: viewModel.clearImportBanner)
            }

            if viewModel.isRecalculatingScores {
                FontScoreProgressBanner(message: viewModel.tr(.recalculatingScores))
            }

            if viewModel.batchSelectionCount > 1 {
                batchToolbar
            }

            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.filteredFonts.isEmpty {
                    Spacer()
                    FontCatalogLoadingView(
                        progress: viewModel.loadProgress,
                        loadingText: viewModel.tr(.loadingFonts),
                        enrichingText: viewModel.tr(.loadingFontsEnriching)
                    )
                    Spacer()
                } else if let errorMessage = viewModel.loadErrorMessage {
                    ContentUnavailableView(
                        viewModel.tr(.loadFailed),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.filteredFonts.isEmpty && viewModel.sidebarFilter != .fontHealth {
                    ContentUnavailableView(
                        viewModel.tr(.noMatchingFonts),
                        systemImage: "magnifyingglass",
                        description: Text(viewModel.tr(.tryClearFilters))
                    )
                } else if viewModel.sidebarFilter == .fontHealth {
                    fontHealthContent
                } else if displayMode == .grid {
                        GeometryReader { proxy in
                            ScrollView {
                                LazyVGrid(
                                    columns: cachedGridColumns,
                                    spacing: gridSpacing
                                ) {
                                    ForEach(viewModel.filteredFonts) { item in
                                        let presentation = viewModel.searchPresentation(for: item)
                                        FontGridCard(
                                            item: item,
                                            primaryTitle: presentation.primary,
                                            secondaryTitle: presentation.secondary,
                                            primaryHighlightRanges: presentation.primaryHighlightRanges,
                                            secondaryHighlightRanges: presentation.secondaryHighlightRanges,
                                            isSelected: viewModel.isBatchSelected(item),
                                            isFavorite: viewModel.isFavorite(item),
                                            previewText: viewModel.previewText,
                                            previewSize: listPreviewSize,
                                            densityMode: densityMode,
                                            language: viewModel.language
                                        ) {
                                            viewModel.handleFontTap(
                                                item,
                                                commandKey: NSEvent.modifierFlags.contains(.command)
                                            )
                                        } onToggleFavorite: {
                                            viewModel.toggleFavorite(item)
                                        }
                                        .contextMenu {
                                            FontOrganizationMenus(viewModel: viewModel, item: item)
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
                            .onAppear {
                                prefetchVisibleGridFonts(from: viewModel.filteredFonts)
                            }
                            .onChange(of: viewModel.filteredFonts.map(\.id)) { _, _ in
                                prefetchVisibleGridFonts(from: viewModel.filteredFonts)
                            }
                        }
                    } else {
                        List(viewModel.filteredFonts) { item in
                            let presentation = viewModel.searchPresentation(for: item)
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text.highlighted(
                                        presentation.primary,
                                        characterRanges: presentation.primaryHighlightRanges
                                    ).font(.system(size: listPreviewSize, weight: .semibold))
                                    Text.highlighted(
                                        presentation.secondary,
                                        characterRanges: presentation.secondaryHighlightRanges
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
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .background(
                                viewModel.isBatchSelected(item)
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .onTapGesture {
                                viewModel.handleFontTap(
                                    item,
                                    commandKey: NSEvent.modifierFlags.contains(.command)
                                )
                            }
                            .contextMenu {
                                FontOrganizationMenus(viewModel: viewModel, item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                        }
                        .listStyle(.inset)
                    }
                }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            displayMode = DisplayMode(rawValue: UserDefaults.standard.string(forKey: "rootfont.displayMode") ?? "grid") ?? .grid
            densityMode = DensityMode(rawValue: UserDefaults.standard.string(forKey: "rootfont.densityMode") ?? "compact") ?? .compact
            let savedPreviewSize = UserDefaults.standard.double(forKey: "rootfont.listPreviewSize")
            let initialSize = savedPreviewSize == 0 ? 18 : savedPreviewSize
            listPreviewSize = initialSize
            listPreviewSizeSlider = initialSize
            searchInput = viewModel.searchQuery
            if !didAutofocusSearch {
                didAutofocusSearch = true
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
        .onChange(of: viewModel.searchFocusToken) { _, _ in
            isSearchFieldFocused = true
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
        .onChange(of: listPreviewSizeSlider) { _, newValue in
            listPreviewSizeDebounceTask?.cancel()
            listPreviewSizeDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if listPreviewSize != newValue {
                        listPreviewSize = newValue
                    }
                }
            }
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
            listPreviewSizeDebounceTask?.cancel()
        }
    }

    private var fontHealthContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                FontHealthReportView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                if !viewModel.filteredFonts.isEmpty {
                    Text(viewModel.tr(.fontHealthAffectedListTitle))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)

                    if displayMode == .grid {
                        LazyVGrid(columns: cachedGridColumns, spacing: gridSpacing) {
                            ForEach(viewModel.filteredFonts) { item in
                                fontHealthGridCard(item: item)
                            }
                        }
                        .padding(.horizontal, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.filteredFonts) { item in
                                fontHealthListRow(item: item)
                                Divider()
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                } else if !viewModel.fontHealthReport.affectedFontIDs.isEmpty {
                    ContentUnavailableView(
                        viewModel.tr(.noMatchingFonts),
                        systemImage: "magnifyingglass",
                        description: Text(viewModel.tr(.tryClearFilters))
                    )
                    .padding(.top, 24)
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func fontHealthGridCard(item: FontItem) -> some View {
        let presentation = viewModel.searchPresentation(for: item)
        FontGridCard(
            item: item,
            primaryTitle: presentation.primary,
            secondaryTitle: presentation.secondary,
            primaryHighlightRanges: presentation.primaryHighlightRanges,
            secondaryHighlightRanges: presentation.secondaryHighlightRanges,
            isSelected: viewModel.isBatchSelected(item),
            isFavorite: viewModel.isFavorite(item),
            healthIssueLabels: viewModel.fontHealthIssues(for: item).map { viewModel.fontHealthIssueLabel($0) },
            previewText: viewModel.previewText,
            previewSize: listPreviewSize,
            densityMode: densityMode,
            language: viewModel.language
        ) {
            viewModel.handleFontTap(
                item,
                commandKey: NSEvent.modifierFlags.contains(.command)
            )
        } onToggleFavorite: {
            viewModel.toggleFavorite(item)
        }
        .contextMenu {
            FontOrganizationMenus(viewModel: viewModel, item: item)
        }
    }

    @ViewBuilder
    private func fontHealthListRow(item: FontItem) -> some View {
        let presentation = viewModel.searchPresentation(for: item)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text.highlighted(
                    presentation.primary,
                    characterRanges: presentation.primaryHighlightRanges
                ).font(.system(size: listPreviewSize, weight: .semibold))
                Text.highlighted(
                    presentation.secondary,
                    characterRanges: presentation.secondaryHighlightRanges
                ).font(.system(size: max(11, listPreviewSize - 2))).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(viewModel.fontHealthIssues(for: item).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                        Text(viewModel.fontHealthIssueLabel(kind))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }
                }
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
        .padding(.vertical, 8)
        .background(
            viewModel.isBatchSelected(item)
                ? Color.accentColor.opacity(0.12)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.handleFontTap(
                item,
                commandKey: NSEvent.modifierFlags.contains(.command)
            )
        }
        .contextMenu {
            FontOrganizationMenus(viewModel: viewModel, item: item)
        }
    }

    private var batchToolbar: some View {
        HStack(spacing: 10) {
            Text(String(format: viewModel.tr(.batchSelectionCount), viewModel.batchSelectionCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(viewModel.tr(.batchFavorite)) {
                viewModel.batchToggleFavorite()
            }
            .controlSize(.small)
            Button(viewModel.tr(.batchActivateSession)) {
                viewModel.batchActivateForSession()
            }
            .controlSize(.small)
            if !viewModel.userTagNames.isEmpty {
                Menu(viewModel.tr(.batchApplyTag)) {
                    ForEach(viewModel.userTagNames, id: \.self) { tag in
                        Button(tag) {
                            viewModel.batchApplyTag(tag)
                        }
                    }
                }
                .controlSize(.small)
            }
            Spacer(minLength: 0)
            Button(viewModel.tr(.batchClearSelection)) {
                viewModel.clearBatchSelection()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
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
                    .accessibilityLabel(viewModel.tr(.searchPlaceholder))
                    .accessibilityIdentifier("fontSearchField")

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
                .accessibilityLabel(viewModel.tr(.source))

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
                .accessibilityLabel(viewModel.tr(.style))

                Picker(viewModel.tr(.sort), selection: Binding(
                    get: { viewModel.sortOption },
                    set: { newValue in
                        viewModel.updateSortOption(newValue)
                    }
                )) {
                    ForEach(SortOption.allCases) { option in
                        Text(viewModel.title(for: option)).tag(option)
                    }
                }
                .controlSize(.regular)
                .frame(minWidth: sortPickerMinWidth)
                .fixedSize()
                .accessibilityLabel(viewModel.tr(.sort))

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
                    .accessibilityLabel(viewModel.tr(.display))
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
                            get: { listPreviewSizeSlider },
                            set: { listPreviewSizeSlider = $0.rounded() }
                        ),
                        in: 2...500
                    )
                        .frame(width: sliderWidth)
                    Text("\(Int(listPreviewSizeSlider))")
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
        case .french, .german, .spanish: return 160
        }
    }

    private var sortPickerMinWidth: CGFloat {
        switch viewModel.language {
        case .english: return 180
        case .simplifiedChinese, .traditionalChinese: return 170
        case .japanese: return 190
        case .korean: return 195
        case .french, .german, .spanish: return 200
        }
    }

    private var segmentedDisplayWidth: CGFloat {
        switch viewModel.language {
        case .english: return 160
        case .simplifiedChinese, .traditionalChinese: return 140
        case .japanese: return 150
        case .korean: return 150
        case .french, .german, .spanish: return 170
        }
    }

    private var segmentedDensityWidth: CGFloat {
        switch viewModel.language {
        case .english: return 200
        case .simplifiedChinese, .traditionalChinese: return 160
        case .japanese: return 190
        case .korean: return 190
        case .french, .german, .spanish: return 220
        }
    }

    private var sliderWidth: CGFloat {
        switch viewModel.language {
        case .english: return 130
        case .simplifiedChinese, .traditionalChinese: return 110
        case .japanese: return 120
        case .korean: return 125
        case .french, .german, .spanish: return 140
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

    private func prefetchVisibleGridFonts(from fonts: [FontItem]) {
        let size = densityMode == .compact ? CGFloat(listPreviewSize) : CGFloat(listPreviewSize + 4)
        let names = fonts.prefix(cachedGridColumnCount * 6).map(\.postScriptName)
        DispatchQueue.global(qos: .utility).async {
            for name in names {
                _ = GridFontCache.shared.font(postScriptName: name, size: size)
            }
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
    let primaryHighlightRanges: [Range<Int>]
    let secondaryHighlightRanges: [Range<Int>]
    let isSelected: Bool
    let isFavorite: Bool
    var healthIssueLabels: [String] = []
    let previewText: String
    let previewSize: Double
    let densityMode: FontListView.DensityMode
    let language: AppLanguage
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false
    @State private var resolvedNSFont: NSFont?
    @State private var fontResolveGeneration = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text.highlighted(primaryTitle, characterRanges: primaryHighlightRanges)
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

            Text.highlighted(secondaryTitle, characterRanges: secondaryHighlightRanges)
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
                ForEach(healthIssueLabels, id: \.self) { label in
                    tag(text: label)
                }
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
        .accessibilityAddTraits(.isButton)
        .onAppear { refreshResolvedFont() }
        .onDisappear { fontResolveGeneration += 1 }
        .onChange(of: item.postScriptName) { _, _ in refreshResolvedFont() }
        .onChange(of: previewSize) { _, _ in refreshResolvedFont() }
        .onChange(of: densityMode) { _, _ in refreshResolvedFont() }
    }

    private func refreshResolvedFont() {
        let size = densityMode == .compact ? CGFloat(previewSize) : CGFloat(previewSize + 4)
        fontResolveGeneration += 1
        let generation = fontResolveGeneration
        let postScriptName = item.postScriptName
        resolvedNSFont = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let font = GridFontCache.shared.font(postScriptName: postScriptName, size: size)
            DispatchQueue.main.async {
                guard generation == self.fontResolveGeneration else { return }
                guard self.item.postScriptName == postScriptName else { return }
                self.resolvedNSFont = font
            }
        }
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
        Text(ProgrammingGradeUI.shortText(for: grade))
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ProgrammingGradeUI.color(for: grade).opacity(0.18), in: Capsule())
            .foregroundStyle(ProgrammingGradeUI.color(for: grade))
            .accessibilityLabel(L10n.tr(ProgrammingGradeUI.l10nKey(for: grade), language: language))
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
        if let font = resolvedNSFont {
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
    Text(ProgrammingGradeUI.shortText(for: grade))
    .font(.caption2.weight(.bold))
    .lineLimit(1)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(ProgrammingGradeUI.color(for: grade).opacity(0.18), in: Capsule())
    .foregroundStyle(ProgrammingGradeUI.color(for: grade))
    .accessibilityLabel(L10n.tr(ProgrammingGradeUI.l10nKey(for: grade), language: language))
}

private struct FontOrganizationMenus: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    let item: FontItem

    var body: some View {
        Menu(viewModel.tr(.addToCollection)) {
            if viewModel.manualCollections.isEmpty {
                Text(viewModel.tr(.noManualCollectionsYet))
            } else {
                ForEach(viewModel.manualCollections) { collection in
                    Button {
                        viewModel.toggleFont(item, inCollection: collection.id)
                    } label: {
                        Label(
                            collection.name,
                            systemImage: viewModel.isFont(item, inCollection: collection.id)
                                ? "checkmark"
                                : "folder"
                        )
                    }
                }
            }
        }

        if !viewModel.userTagNames.isEmpty {
            Menu(viewModel.tr(.fontTags)) {
                ForEach(viewModel.userTagNames, id: \.self) { tag in
                    Button {
                        viewModel.toggleTag(tag, on: item)
                    } label: {
                        Label(
                            tag,
                            systemImage: viewModel.hasTag(tag, on: item) ? "checkmark" : "tag"
                        )
                    }
                }
            }
        }
    }
}
