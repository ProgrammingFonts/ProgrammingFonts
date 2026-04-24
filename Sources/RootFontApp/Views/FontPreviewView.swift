import AppKit
import CoreText
import SwiftUI

struct FontPreviewView: View {
    private enum PreviewSurface: String, CaseIterable, Identifiable {
        case sample
        case code
        var id: Self { self }
    }

    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var previewPreset: FontBrowserViewModel.PreviewPreset = .mixed
    @State private var previewSurface: PreviewSurface = .sample
    @State private var codeLanguage: MiniTokenizer.Language = .swift
    @State private var codeSnippet: String = FontPreviewView.defaultSnippet(for: .swift)
    @State private var useSingleLinePreview = false
    @State private var useMonospacedDigits = false
    @State private var expandedLetterSpacing = false
    @State private var ligaturesEnabled = true
    @State private var zeroVariantEnabled = false
    @State private var enabledStylisticSetTags: Set<String> = []
    @State private var showScoreBreakdown = false
    @State private var activeWhyFactor: ProgrammingScoreFactor?
    @State private var compareFontID: String?
    @State private var showCopyToast = false
    @State private var activationMessage: String?
    @State private var activationConflictPath: String?
    @State private var fontBookMessage: String?
    @State private var fontBookPathHint: String?
    @State private var showInstallConfirm = false

    /// Texts under this length keep the ZWSP soft-wrap treatment.
    /// Larger inputs fall back to the native layout engine because the
    /// per-character joined string grows rapidly (O(n) strings, extra
    /// allocations) and Text layout slows down noticeably.
    private let softWrapCharacterLimit = 400
    /// Any preview text longer than this is truncated with a visible
    /// hint so the preview area stays responsive.
    private let previewTextLengthLimit = 2000
    private let miniTokenizer = MiniTokenizer()
    private let featureBinder: OpenTypeFeatureBinding = OpenTypeFeatureBinder()
    private let configExporter = EditorConfigExporter()
    private let activationService: FontActivationServiceProtocol = FontActivationService()

    var body: some View {
        Group {
            if let selected = viewModel.selectedFont {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(for: selected)
                        previewSurfaceSection
                        if previewSurface == .sample {
                            quickSampleSection
                            previewTextField
                        } else {
                            codeLanguageSection
                        }
                        previewSizeSection
                        if previewSurface == .sample {
                            previewModeSection
                        }
                        typographyOptionsSection
                        featureToggleSection(for: selected)
                        if selected.programming?.isMonospaced == true,
                           let score = selected.programmingScore {
                            if shouldShowWhyNotHint(score: score) {
                                whyNotHint(score: score)
                            }
                            compareSection(baseline: selected, baselineScore: score)
                            scoreBreakdownSection(score: score)
                        }
                        if previewSurface == .sample {
                            previewBlocksSection(for: selected)
                        } else {
                            codePreviewSection(for: selected)
                        }
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
        .onChange(of: viewModel.selectedFont?.id, initial: true) { _, _ in
            guard let selected = viewModel.selectedFont else { return }
            loadFeaturePreferences(for: selected)
        }
        .onChange(of: ligaturesEnabled) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .onChange(of: zeroVariantEnabled) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .onChange(of: enabledStylisticSetTags) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .alert(viewModel.tr(.installConfirmTitle), isPresented: $showInstallConfirm) {
            Button(viewModel.tr(.installConfirmAction)) {
                if let selected = viewModel.selectedFont {
                    performActivation {
                        try activationService.installForUser(fontID: selected.postScriptName)
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(viewModel.tr(.installConfirmMessage))
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
                Menu(viewModel.tr(.copyEditorConfig)) {
                    ForEach(EditorTarget.allCases) { target in
                        Button(editorTitle(target)) {
                            copyEditorConfig(target: target, postScriptName: selected.postScriptName)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Text(selected.postScriptName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(viewModel.tr(.openInFontBook)) {
                    openInFontBook(for: selected)
                }
                .buttonStyle(.link)
                .fixedSize()
            }
            if showCopyToast {
                Text(viewModel.tr(.copiedToClipboard))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
            if let fontBookMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fontBookMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let fontBookPathHint {
                        Text("\(viewModel.tr(.fontPathPrefix)): \(fontBookPathHint)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            if selected.source == .user {
                HStack(spacing: 8) {
                    Button(viewModel.tr(.activateForSession)) {
                        performActivation {
                            try activationService.activateForProcess(fontID: selected.postScriptName)
                        }
                    }
                    .controlSize(.small)
                    Button(viewModel.tr(.installForAllApps)) {
                        showInstallConfirm = true
                    }
                    .controlSize(.small)
                    if activationService.isManaged(fontID: selected.postScriptName) {
                        Button(viewModel.tr(.uninstallManagedFont)) {
                            performActivation {
                                try activationService.uninstall(fontID: selected.postScriptName)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                if let activationMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activationMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let activationConflictPath {
                            Text("\(viewModel.tr(.activationConflictPrefix)): \(activationConflictPath)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                Button(viewModel.tr(.openManagedFontsFolder)) {
                    NSWorkspace.shared.open(activationService.managedFontsDirectoryURL())
                }
                .controlSize(.small)
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

    private var previewSurfaceSection: some View {
        Picker(viewModel.tr(.previewMode), selection: $previewSurface) {
            Text(viewModel.tr(.previewModeSample)).tag(PreviewSurface.sample)
            Text(viewModel.tr(.previewModeCode)).tag(PreviewSurface.code)
        }
        .pickerStyle(.segmented)
    }

    private var codeLanguageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(viewModel.tr(.codeLanguage), selection: $codeLanguage) {
                Text("Swift").tag(MiniTokenizer.Language.swift)
                Text("TypeScript").tag(MiniTokenizer.Language.typescript)
                Text("Python").tag(MiniTokenizer.Language.python)
                Text("Rust").tag(MiniTokenizer.Language.rust)
                Text("Go").tag(MiniTokenizer.Language.go)
                Text("JSON").tag(MiniTokenizer.Language.json)
                Text("Shell").tag(MiniTokenizer.Language.shell)
                Text("CSS").tag(MiniTokenizer.Language.css)
            }
            .pickerStyle(.menu)

            TextEditor(text: $codeSnippet)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                )
        }
        .onChange(of: codeLanguage) { _, newLanguage in
            codeSnippet = Self.defaultSnippet(for: newLanguage)
        }
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
    private func featureToggleSection(for selected: FontItem) -> some View {
        if let profile = selected.programming, profile.isMonospaced {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tr(.featureSection))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(viewModel.tr(.featureLigatures), isOn: $ligaturesEnabled)
                    .toggleStyle(.switch)
                if profile.hasZeroVariant {
                    Toggle(viewModel.tr(.featureZeroVariant), isOn: $zeroVariantEnabled)
                        .toggleStyle(.switch)
                }
                if !profile.availableStylisticSets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(profile.availableStylisticSets, id: \.tag) { set in
                                Button(set.tag.uppercased()) {
                                    if enabledStylisticSetTags.contains(set.tag) {
                                        enabledStylisticSetTags.remove(set.tag)
                                    } else {
                                        enabledStylisticSetTags.insert(set.tag)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(enabledStylisticSetTags.contains(set.tag) ? .accentColor : .secondary)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func scoreBreakdownSection(score: ProgrammingScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showScoreBreakdown) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(score.breakdown, id: \.factor) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(factorTitle(item.factor))
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 8)
                                Button(whyButtonTitle()) {
                                    activeWhyFactor = item.factor
                                }
                                .buttonStyle(.plain)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                                .popover(isPresented: Binding(
                                    get: { activeWhyFactor == item.factor },
                                    set: { showing in
                                        if !showing, activeWhyFactor == item.factor {
                                            activeWhyFactor = nil
                                        }
                                    }
                                ), arrowEdge: .bottom) {
                                    whyPopover(for: item.factor)
                                }
                                Text("\(Int(round(item.weightedValue)))/\(Int(round(item.maxWeight)))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: item.weightedValue, total: item.maxWeight)
                                .controlSize(.small)
                            Text(factorHint(item.factor))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 8) {
                    Text(scoreBreakdownTitle())
                        .font(.subheadline.weight(.semibold))
                    gradeBadge(score.grade)
                    Text("\(score.total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func compareSection(baseline: FontItem, baselineScore: ProgrammingScore) -> some View {
        let candidates = compareCandidates(for: baseline)
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Picker(compareTitle(), selection: Binding(
                    get: { compareFontID ?? "" },
                    set: { compareFontID = $0.isEmpty ? nil : $0 }
                )) {
                    Text(compareNoneOption()).tag("")
                    ForEach(candidates) { item in
                        Text(item.familyName(for: viewModel.language)).tag(item.id)
                    }
                }
                .pickerStyle(.menu)

                if let compare = selectedCompareFont(from: candidates),
                   let compareScore = compare.programmingScore {
                    FontCompareView(
                        baseline: baseline,
                        candidate: compare,
                        baselineScore: baselineScore,
                        candidateScore: compareScore,
                        codeSnippet: highlightedCode(for: codeSnippet),
                        baselineFont: previewFont(for: baseline, size: max(12, viewModel.previewSize * 0.82), monospacedNumerals: true),
                        candidateFont: previewFont(for: compare, size: max(12, viewModel.previewSize * 0.82), monospacedNumerals: true),
                        factorTitle: factorTitle,
                        tr: viewModel.tr
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func factorTitle(_ factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline:
            return viewModel.tr(.factorMonospaceBaseline)
        case .glyphDisambiguation:
            return viewModel.tr(.factorGlyphDisambiguation)
        case .ligatureSupport:
            return viewModel.tr(.factorLigatureSupport)
        case .stylisticFlexibility:
            return viewModel.tr(.factorStylisticFlexibility)
        case .boxDrawing:
            return viewModel.tr(.factorBoxDrawing)
        case .powerlineGlyphs:
            return viewModel.tr(.factorPowerlineGlyphs)
        case .nerdFontCoverage:
            return viewModel.tr(.factorNerdFontCoverage)
        case .variableFont:
            return viewModel.tr(.factorVariableFont)
        case .languageCoverage:
            return viewModel.tr(.factorLanguageCoverage)
        case .weightVariety:
            return viewModel.tr(.factorWeightVariety)
        }
    }

    private func factorHint(_ factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline:
            return viewModel.tr(.factorHintMonospaceBaseline)
        case .glyphDisambiguation:
            return viewModel.tr(.factorHintGlyphDisambiguation)
        case .ligatureSupport:
            return viewModel.tr(.factorHintLigatureSupport)
        case .stylisticFlexibility:
            return viewModel.tr(.factorHintStylisticFlexibility)
        case .boxDrawing:
            return viewModel.tr(.factorHintBoxDrawing)
        case .powerlineGlyphs:
            return viewModel.tr(.factorHintPowerlineGlyphs)
        case .nerdFontCoverage:
            return viewModel.tr(.factorHintNerdFontCoverage)
        case .variableFont:
            return viewModel.tr(.factorHintVariableFont)
        case .languageCoverage:
            return viewModel.tr(.factorHintLanguageCoverage)
        case .weightVariety:
            return viewModel.tr(.factorHintWeightVariety)
        }
    }

    @ViewBuilder
    private func whyPopover(for factor: ProgrammingScoreFactor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(whyTitle(for: factor))
                .font(.subheadline.weight(.semibold))
            Text(viewModel.tr(.whyMeasurementTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(factorHint(factor))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.tr(.whyImpactTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(whyDescription(for: factor))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.tr(.whyExampleTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(whyExample(for: factor))
                .font(.caption2.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(width: 300)
    }

    private func scoreBreakdownTitle() -> String {
        viewModel.tr(.scoreBreakdownTitle)
    }

    private func shouldShowWhyNotHint(score: ProgrammingScore) -> Bool {
        score.grade == .c || score.grade == .notRecommended
    }

    @ViewBuilder
    private func whyNotHint(score: ProgrammingScore) -> some View {
        let weakest = weakestContributions(from: score.breakdown, limit: 3)
        let summary = weakest.map { item in
            "\(factorTitle(item.factor)) \(Int(round(item.weightedValue)))/\(Int(round(item.maxWeight)))"
        }.joined(separator: " · ")

        Label(
            whyNotTitleText() + " " + summary,
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        HStack(spacing: 8) {
            Button(viewModel.tr(.whyInspectFactors)) {
                showScoreBreakdown = true
                previewSurface = .code
            }
            .controlSize(.small)
            Button(viewModel.tr(.whyCompareNow)) {
                previewSurface = .code
            }
            .controlSize(.small)
        }
    }

    private func weakestContributions(
        from breakdown: [FactorContribution],
        limit: Int
    ) -> [FactorContribution] {
        breakdown
            .sorted { lhs, rhs in
                let lRatio = lhs.maxWeight > 0 ? lhs.weightedValue / lhs.maxWeight : 0
                let rRatio = rhs.maxWeight > 0 ? rhs.weightedValue / rhs.maxWeight : 0
                if lRatio == rRatio {
                    return lhs.weightedValue < rhs.weightedValue
                }
                return lRatio < rRatio
            }
            .prefix(limit)
            .map { $0 }
    }

    private func whyNotTitleText() -> String {
        viewModel.tr(.whyNotRecommended)
    }

    private func compareCandidates(for baseline: FontItem) -> [FontItem] {
        viewModel.filteredFonts.filter { item in
            item.id != baseline.id &&
            item.programming?.isMonospaced == true &&
            item.programmingScore != nil
        }
    }

    private func selectedCompareFont(from candidates: [FontItem]) -> FontItem? {
        if let compareFontID, let found = candidates.first(where: { $0.id == compareFontID }) {
            return found
        }
        return candidates.first
    }

    private func compareTitle() -> String {
        viewModel.tr(.compareWith)
    }

    private func compareNoneOption() -> String {
        viewModel.tr(.compareNone)
    }

    private func whyButtonTitle() -> String {
        viewModel.tr(.whyButton)
    }

    private func whyTitle(for factor: ProgrammingScoreFactor) -> String {
        "\(factorTitle(factor)) · \(viewModel.tr(.whyItMattersSuffix))"
    }

    private func whyDescription(for factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline:
            return viewModel.tr(.factorWhyMonospaceBaseline)
        case .glyphDisambiguation:
            return viewModel.tr(.factorWhyGlyphDisambiguation)
        case .ligatureSupport:
            return viewModel.tr(.factorWhyLigatureSupport)
        case .stylisticFlexibility:
            return viewModel.tr(.factorWhyStylisticFlexibility)
        case .boxDrawing:
            return viewModel.tr(.factorWhyBoxDrawing)
        case .powerlineGlyphs:
            return viewModel.tr(.factorWhyPowerlineGlyphs)
        case .nerdFontCoverage:
            return viewModel.tr(.factorWhyNerdFontCoverage)
        case .variableFont:
            return viewModel.tr(.factorWhyVariableFont)
        case .languageCoverage:
            return viewModel.tr(.factorWhyLanguageCoverage)
        case .weightVariety:
            return viewModel.tr(.factorWhyWeightVariety)
        }
    }

    private func whyExample(for factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline: return "let x = 10\nlet longName = 20"
        case .glyphDisambiguation: return "Il1  O0  rn/m  8B"
        case .ligatureSupport: return "!=  >=  <=  =>  ->"
        case .stylisticFlexibility: return "0  0̸  ss01  ss02"
        case .boxDrawing: return "┌─┬─┐\n│ │ │\n└─┴─┘"
        case .powerlineGlyphs: return "      "
        case .nerdFontCoverage: return "󰈙  󰄛  󰆍  󰒓"
        case .variableFont: return "wght: 400 -> 550"
        case .languageCoverage: return "Hello 你好 Привет"
        case .weightVariety: return "Thin Regular Medium Bold"
        }
    }

    private func gradeBadge(_ grade: ProgrammingGrade) -> some View {
        Text(gradeText(grade))
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
        .accessibilityLabel(viewModel.tr(gradeL10nKey(grade)))
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
        let prepared = preparedPreviewText(text)
        if useSingleLinePreview {
            VStack(alignment: .leading, spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(prepared.renderText)
                        .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                        .tracking(expandedLetterSpacing ? 0.5 : 0)
                        .lineLimit(1)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3))
                .cornerRadius(10)
                if prepared.didTruncate {
                    previewTruncationHint(originalCount: prepared.originalCount)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(prepared.renderText)
                    .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                    .tracking(expandedLetterSpacing ? 0.5 : 0)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary.opacity(0.3))
                    .cornerRadius(10)
                if prepared.didTruncate {
                    previewTruncationHint(originalCount: prepared.originalCount)
                }
            }
        }
    }

    @ViewBuilder
    private func codePreviewSection(for item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.tr(.codePreviewTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlightedCode(for: codeSnippet))
                    .font(previewFont(for: item, size: max(12, viewModel.previewSize * 0.86), monospacedNumerals: true))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.quaternary.opacity(0.28))
            .cornerRadius(10)

            ambiguityLensSection(for: item)

            Text(viewModel.tr(.waterfallTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach([11.0, 12.0, 13.0, 14.0, 16.0, 18.0], id: \.self) { size in
                    HStack(spacing: 8) {
                        Text("\(Int(size)) pt")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Text(highlightedCode(for: codeSnippet))
                            .font(previewFont(for: item, size: size, monospacedNumerals: true))
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.2))
            .cornerRadius(10)

            glyphMatrixSection(for: item)
        }
    }

    @ViewBuilder
    private func ambiguityLensSection(for item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.tr(.ambiguityLensTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Il1 O0 8B 5S 9gq rnm co ci {}()[] ,.;:")
                .font(previewFont(for: item, size: 32, monospacedNumerals: true))
                .lineLimit(1)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func glyphMatrixSection(for item: FontItem) -> some View {
        if let profile = item.programming,
           profile.hasPowerlineGlyphs || profile.hasNerdFontGlyphs {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tr(.glyphMatrixTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if profile.hasPowerlineGlyphs {
                    glyphGrid(
                        title: viewModel.tr(.powerlineGlyphsTitle),
                        entries: [("\u{E0A0}", "E0A0"), ("\u{E0A3}", "E0A3"), ("\u{E0B0}", "E0B0"), ("\u{E0B3}", "E0B3")],
                        item: item
                    )
                }
                if profile.hasNerdFontGlyphs {
                    glyphGrid(
                        title: viewModel.tr(.nerdFontGlyphsTitle),
                        entries: [("\u{E5FA}", "E5FA"), ("\u{E62B}", "E62B"), ("\u{F013}", "F013"), ("\u{F0C8}", "F0C8"), ("\u{F120}", "F120"), ("\u{F489}", "F489")],
                        item: item
                    )
                }
            }
        }
    }

    private func glyphGrid(title: String, entries: [(String, String)], item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                ForEach(entries, id: \.1) { entry in
                    VStack(spacing: 2) {
                        Text(entry.0)
                            .font(previewFont(for: item, size: 24, monospacedNumerals: true))
                        Text("U+\(entry.1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func highlightedCode(for text: String) -> AttributedString {
        let mutable = NSMutableAttributedString(string: text)
        let tokens = miniTokenizer.tokenize(text, language: codeLanguage)
        for token in tokens {
            guard token.range.location != NSNotFound else { continue }
            let color: NSColor
            switch token.kind {
            case .keyword:
                color = .systemBlue
            case .type:
                color = .systemMint
            case .string:
                color = .systemOrange
            case .number:
                color = .systemPurple
            case .comment:
                color = .secondaryLabelColor
            case .punctuation, .operator:
                color = .systemPink
            case .identifier:
                color = .labelColor
            }
            mutable.addAttribute(.foregroundColor, value: color, range: token.range)
        }
        return (try? AttributedString(NSAttributedString(attributedString: mutable), including: \.appKit)) ?? AttributedString(text)
    }

    private struct PreparedPreviewText {
        let renderText: String
        let didTruncate: Bool
        let originalCount: Int
    }

    private func preparedPreviewText(_ text: String) -> PreparedPreviewText {
        let originalCount = text.count
        let base: String
        let didTruncate: Bool
        if originalCount > previewTextLengthLimit {
            let cutoff = text.index(text.startIndex, offsetBy: previewTextLengthLimit)
            base = String(text[..<cutoff]) + "…"
            didTruncate = true
        } else {
            base = text
            didTruncate = false
        }

        let rendered: String
        if base.count > softWrapCharacterLimit {
            rendered = base
        } else {
            rendered = softWrappedText(base)
        }
        return PreparedPreviewText(
            renderText: rendered,
            didTruncate: didTruncate,
            originalCount: originalCount
        )
    }

    @ViewBuilder
    private func previewTruncationHint(originalCount: Int) -> some View {
        Label(
            String(format: viewModel.tr(.previewTruncatedInfo), previewTextLengthLimit, originalCount),
            systemImage: "scissors"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func softWrappedText(_ text: String) -> String {
        var result = String()
        result.reserveCapacity(text.count * 4)
        var first = true
        for character in text {
            if first {
                first = false
            } else {
                result.append("\u{200B}")
            }
            result.append(character)
        }
        return result
    }

    private func previewFont(for item: FontItem, size: Double, monospacedNumerals: Bool) -> Font {
        if monospacedNumerals && previewSurface == .sample {
            return .system(size: size, design: .monospaced)
        }
        if let baseFont = NSFont(name: item.postScriptName, size: size) {
            let bound = featureBinder.bind(
                base: baseFont,
                options: OpenTypeFeatureOptions(
                    ligaturesEnabled: ligaturesEnabled,
                    zeroVariantEnabled: zeroVariantEnabled,
                    stylisticSetTags: enabledStylisticSetTags
                )
            )
            return Font(bound)
        }
        return .system(size: size)
    }

    private static func defaultSnippet(for language: MiniTokenizer.Language) -> String {
        switch language {
        case .swift:
            return "import Foundation\n\nstruct User {\n    let id: Int\n    let name: String\n}\n\nfunc greet(_ user: User) -> String {\n    return \"Hello, \\(user.name)!\"\n}"
        case .typescript:
            return "interface User { id: number; name: string }\n\nconst greet = (user: User): string => {\n  return `Hello, ${user.name}!`\n}"
        case .python:
            return "from dataclasses import dataclass\n\n@dataclass\nclass User:\n    id: int\n    name: str\n\ndef greet(user: User) -> str:\n    return f\"Hello, {user.name}!\""
        case .rust:
            return "struct User { id: u64, name: String }\n\nfn greet(user: &User) -> String {\n    format!(\"Hello, {}!\", user.name)\n}"
        case .go:
            return "type User struct { ID int; Name string }\n\nfunc Greet(user User) string {\n    return fmt.Sprintf(\"Hello, %s!\", user.Name)\n}"
        case .json:
            return "{\n  \"theme\": \"dark\",\n  \"font\": \"JetBrains Mono\",\n  \"size\": 14,\n  \"ligatures\": true\n}"
        case .shell:
            return "#!/usr/bin/env bash\nset -euo pipefail\n\nname=\"RootFont\"\necho \"Hello, ${name}\""
        case .css:
            return ":root {\n  --font-main: \"JetBrains Mono\";\n  --font-size: 14px;\n}\n\n.editor {\n  font-family: var(--font-main);\n  font-size: var(--font-size);\n}"
        }
    }

    private func loadFeaturePreferences(for selected: FontItem) {
        guard let profile = selected.programming, profile.isMonospaced else {
            ligaturesEnabled = true
            zeroVariantEnabled = false
            enabledStylisticSetTags = []
            return
        }
        if let saved = viewModel.featurePreferences(forFontID: selected.id) {
            ligaturesEnabled = saved.ligaturesEnabled
            zeroVariantEnabled = profile.hasZeroVariant ? saved.zeroVariantEnabled : false
            let availableSets = Set(profile.availableStylisticSets.map { $0.tag.lowercased() })
            let savedSets = Set(saved.stylisticSetTags.map { $0.lowercased() })
            enabledStylisticSetTags = availableSets.intersection(savedSets)
        } else {
            ligaturesEnabled = profile.hasProgrammingLigatures
            zeroVariantEnabled = false
            enabledStylisticSetTags = []
        }
    }

    private func persistFeaturePreferencesIfPossible() {
        guard let selected = viewModel.selectedFont,
              let profile = selected.programming,
              profile.isMonospaced else { return }
        let normalizedSets = Set(profile.availableStylisticSets.map { $0.tag.lowercased() })
        let prefs = FontFeaturePreferences(
            ligaturesEnabled: ligaturesEnabled,
            zeroVariantEnabled: profile.hasZeroVariant ? zeroVariantEnabled : false,
            stylisticSetTags: enabledStylisticSetTags.intersection(normalizedSets)
        )
        viewModel.updateFeaturePreferences(prefs, forFontID: selected.id)
    }

    private func editorTitle(_ target: EditorTarget) -> String {
        switch target {
        case .vscode: return viewModel.tr(.editorVSCode)
        case .cursor: return viewModel.tr(.editorCursor)
        case .alacritty: return viewModel.tr(.editorAlacritty)
        case .kitty: return viewModel.tr(.editorKitty)
        case .warp: return viewModel.tr(.editorWarp)
        case .zed: return viewModel.tr(.editorZed)
        }
    }

    private func copyEditorConfig(target: EditorTarget, postScriptName: String) {
        let snippet = configExporter.snippet(
            target: target,
            postScriptName: postScriptName,
            size: Int(viewModel.previewSize.rounded()),
            ligaturesEnabled: ligaturesEnabled
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            showCopyToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                showCopyToast = false
            }
        }
    }

    private func openInFontBook(for item: FontItem) {
        fontBookMessage = nil
        fontBookPathHint = nil
        guard let url = resolveFontURL(postScriptName: item.postScriptName) else {
            fontBookMessage = viewModel.tr(.fontBookOpenFailed)
            return
        }
        if NSWorkspace.shared.open(url) {
            return
        }
        fontBookMessage = viewModel.tr(.fontBookOpenFailed)
        fontBookPathHint = url.path
    }

    private func resolveFontURL(postScriptName: String) -> URL? {
        guard let urls = CTFontManagerCopyAvailableFontURLs() as? [URL] else {
            return nil
        }
        return urls.first { url in
            url.deletingPathExtension().lastPathComponent == postScriptName
        }
    }

    private func performActivation(_ operation: @escaping () throws -> Void) {
        Task { @MainActor in
            do {
                try operation()
                activationMessage = viewModel.tr(.activationDone)
                activationConflictPath = nil
            } catch let FontActivationError.installConflict(destination) {
                activationMessage = viewModel.tr(.activationConflict)
                activationConflictPath = destination.path
            } catch {
                activationMessage = viewModel.tr(.activationFailed)
                activationConflictPath = nil
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            activationMessage = nil
            activationConflictPath = nil
        }
    }
}
