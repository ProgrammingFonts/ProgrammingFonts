import SwiftUI

struct FontPreviewProgrammingPanel: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    let baseline: FontItem
    let baselineScore: ProgrammingScore
    let factorLabels: FontPreviewFactorLabels
    @Binding var previewSurface: FontPreviewSurface
    @Binding var showScoreBreakdown: Bool
    @Binding var activeWhyFactor: ProgrammingScoreFactor?
    @Binding var compareFontID: String?
    @Binding var snippetStrategy: SnippetStrategy
    @Binding var codeLanguage: MiniTokenizer.Language
    let codeSnippet: String
    let highlightedCode: (String) -> AttributedString
    let previewFont: (FontItem, Double, Bool) -> Font
    let codeLanguageTitle: (MiniTokenizer.Language) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if shouldShowWhyNotHint(score: baselineScore) {
                whyNotHint(score: baselineScore)
            }
            compareSection
            scoreBreakdownSection(score: baselineScore)
        }
    }

    @ViewBuilder
    private var compareSection: some View {
        let candidates = compareCandidates
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                compareSnippetControls
                Picker(viewModel.tr(.compareWith), selection: Binding(
                    get: { compareFontID ?? "" },
                    set: { compareFontID = $0.isEmpty ? nil : $0 }
                )) {
                    Text(viewModel.tr(.compareNone)).tag("")
                    ForEach(candidates) { item in
                        Text(item.familyName(for: viewModel.language)).tag(item.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(viewModel.tr(.compareWith))

                if let compare = selectedCompareFont(from: candidates),
                   let compareScore = compare.programmingScore {
                    FontCompareView(
                        baseline: baseline,
                        candidate: compare,
                        baselineFamilyName: baseline.familyName(for: viewModel.language),
                        candidateFamilyName: compare.familyName(for: viewModel.language),
                        plainCodeSnippet: codeSnippet,
                        baselineScore: baselineScore,
                        candidateScore: compareScore,
                        codeSnippet: highlightedCode(codeSnippet),
                        baselineFont: previewFont(baseline, max(12, viewModel.previewSize * 0.82), true),
                        candidateFont: previewFont(compare, max(12, viewModel.previewSize * 0.82), true),
                        factorTitle: factorLabels.title,
                        bucketTitle: factorLabels.bucketTitle,
                        tr: viewModel.tr
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var compareSnippetControls: some View {
        HStack(spacing: 8) {
            Picker(viewModel.tr(.snippetStrategy), selection: $snippetStrategy) {
                Text(viewModel.tr(.snippetStrategySemantic)).tag(SnippetStrategy.semantic)
                Text(viewModel.tr(.snippetStrategyNative)).tag(SnippetStrategy.native)
            }
            .pickerStyle(.menu)

            Picker(viewModel.tr(.codeLanguage), selection: $codeLanguage) {
                ForEach(MiniTokenizer.Language.allCases) { language in
                    Text(codeLanguageTitle(language)).tag(language)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func scoreBreakdownSection(score: ProgrammingScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showScoreBreakdown) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(score.breakdown, id: \.factor) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(factorLabels.title(item.factor))
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 8)
                                Button(viewModel.tr(.whyButton)) {
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
                            Text(factorLabels.hint(item.factor))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.tr(.scoreBreakdownTitle))
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
    private func whyPopover(for factor: ProgrammingScoreFactor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(factorLabels.title(factor)) · \(viewModel.tr(.whyItMattersSuffix))")
                .font(.subheadline.weight(.semibold))
            Text(viewModel.tr(.whyMeasurementTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(factorLabels.hint(factor))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.tr(.whyImpactTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(factorLabels.whyDescription(factor))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.tr(.whyExampleTitle))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(factorLabels.whyExample(factor))
                .font(.caption2.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(width: 300)
    }

    private func shouldShowWhyNotHint(score: ProgrammingScore) -> Bool {
        score.grade == .c || score.grade == .notRecommended
    }

    @ViewBuilder
    private func whyNotHint(score: ProgrammingScore) -> some View {
        let weakest = weakestContributions(from: score.breakdown, limit: 3)
        let summary = weakest.map { item in
            "\(factorLabels.title(item.factor)) \(Int(round(item.weightedValue)))/\(Int(round(item.maxWeight)))"
        }.joined(separator: " · ")

        Label(
            viewModel.tr(.whyNotRecommended) + " " + summary,
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

    private var compareCandidates: [FontItem] {
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
}
