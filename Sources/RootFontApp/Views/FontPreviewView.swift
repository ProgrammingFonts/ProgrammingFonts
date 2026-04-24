import AppKit
import SwiftUI

struct FontPreviewView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var previewPreset: FontBrowserViewModel.PreviewPreset = .mixed
    @State private var useSingleLinePreview = false
    @State private var useMonospacedDigits = false
    @State private var expandedLetterSpacing = false
    @State private var showScoreBreakdown = false
    @State private var activeWhyFactor: ProgrammingScoreFactor?
    @State private var compareFontID: String?

    /// Texts under this length keep the ZWSP soft-wrap treatment.
    /// Larger inputs fall back to the native layout engine because the
    /// per-character joined string grows rapidly (O(n) strings, extra
    /// allocations) and Text layout slows down noticeably.
    private let softWrapCharacterLimit = 400
    /// Any preview text longer than this is truncated with a visible
    /// hint so the preview area stays responsive.
    private let previewTextLengthLimit = 2000

    var body: some View {
        Group {
            if let selected = viewModel.selectedFont {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(for: selected)
                        quickSampleSection
                        previewTextField
                        previewSizeSection
                        previewModeSection
                        typographyOptionsSection
                        if selected.programming?.isMonospaced == true,
                           let score = selected.programmingScore {
                            if shouldShowWhyNotHint(score: score) {
                                whyNotHint(score: score)
                            }
                            compareSection(baseline: selected, baselineScore: score)
                            scoreBreakdownSection(score: score)
                        }
                        previewBlocksSection(for: selected)
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
                Text(selected.postScriptName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    let totalDelta = compareScore.total - baselineScore.total
                    HStack(spacing: 8) {
                        Text(compareDeltaTitle())
                            .font(.caption.weight(.semibold))
                        Text(formatSigned(totalDelta))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(totalDelta >= 0 ? .green : .orange)
                    }

                    let deltas = ProgrammingScoreEngine.factorDeltas(
                        baseline: baselineScore,
                        candidate: compareScore
                    )
                    ForEach(deltas.prefix(4), id: \.factor) { item in
                        HStack(spacing: 8) {
                            Text(factorTitle(item.factor))
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(formatSigned(item.delta))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(item.delta >= 0 ? .green : .orange)
                        }
                    }
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
            Text(whyDescription(for: factor))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private func compareDeltaTitle() -> String {
        viewModel.tr(.scoreDelta)
    }

    private func formatSigned(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private func formatSigned(_ value: Double) -> String {
        let rounded = Int(round(value))
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
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
        Text({
            switch grade {
            case .s: return "S"
            case .a: return "A"
            case .b: return "B"
            case .c: return "C"
            case .notRecommended: return "NR"
            }
        }())
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
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
        if monospacedNumerals {
            return .system(size: size, design: .monospaced)
        }
        if let font = NSFont(name: item.postScriptName, size: size) {
            return Font(font)
        }
        return .system(size: size)
    }
}
