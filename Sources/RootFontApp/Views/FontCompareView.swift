import SwiftUI

struct FontCompareView: View {
    let baseline: FontItem
    let candidate: FontItem
    let baselineScore: ProgrammingScore
    let candidateScore: ProgrammingScore
    let codeSnippet: AttributedString
    let baselineFont: Font
    let candidateFont: Font
    let factorTitle: (ProgrammingScoreFactor) -> String
    let tr: (L10nKey) -> String
    @State private var displayMode: CompareDisplayMode = .sideBySide
    @State private var overlayOpacity: Double = 0.55
    @State private var overlayVisibility: OverlayVisibility = .both

    private var totalDelta: Int {
        candidateScore.total - baselineScore.total
    }

    private var topFactorDeltas: [FactorDelta] {
        ProgrammingScoreEngine.factorDeltas(
            baseline: baselineScore,
            candidate: candidateScore
        )
        .prefix(6)
        .map { $0 }
    }

    private var coverage: CoverageDiff {
        CoverageDiff(baseline: baseline.programming, candidate: candidate.programming)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(tr(.scoreDelta))
                    .font(.caption.weight(.semibold))
                Text(formatSigned(totalDelta))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(totalDelta >= 0 ? .green : .orange)
                Spacer(minLength: 0)
                Text("\(baselineScore.total) -> \(candidateScore.total)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Picker(tr(.compareDisplayMode), selection: $displayMode) {
                ForEach(CompareDisplayMode.allCases) { mode in
                    Text(mode.title(tr)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if displayMode == .sideBySide {
                HStack(alignment: .top, spacing: 10) {
                    compareColumn(title: baseline.familyName, attributed: codeSnippet, font: baselineFont)
                    compareColumn(title: candidate.familyName, attributed: codeSnippet, font: candidateFont)
                }
            } else {
                overlayControls
                overlayComparePanel
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(topFactorDeltas, id: \.factor) { item in
                    HStack(spacing: 8) {
                        Text(factorTitle(item.factor))
                            .font(.caption2)
                        Spacer(minLength: 8)
                        Text(formatSigned(item.delta))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(item.delta >= 0 ? .green : .orange)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(tr(.coverageDiffTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    coverageTags(title: tr(.coverageOnlyBaseline), buckets: coverage.baselineOnly)
                    coverageTags(title: tr(.coverageOnlyCandidate), buckets: coverage.candidateOnly)
                    coverageTags(title: tr(.coverageBoth), buckets: coverage.both)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(tr(.compareOverlayOpacity))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $overlayOpacity, in: 0.1 ... 1.0)
            }
            Picker(tr(.compareOverlayVisibility), selection: $overlayVisibility) {
                ForEach(OverlayVisibility.allCases) { visibility in
                    Text(visibility.title(tr)).tag(visibility)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var overlayComparePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(baseline.familyName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(candidate.familyName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    if overlayVisibility.showsBaseline {
                        Text(codeSnippet)
                            .font(baselineFont)
                            .lineLimit(3)
                            .foregroundStyle(.primary.opacity(overlayVisibility.showsCandidate ? overlayOpacity : 1.0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if overlayVisibility.showsCandidate {
                        Text(codeSnippet)
                            .font(candidateFont)
                            .lineLimit(3)
                            .foregroundStyle(Color.accentColor.opacity(overlayVisibility.showsBaseline ? overlayOpacity : 1.0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func compareColumn(title: String, attributed: AttributedString, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(attributed)
                    .font(font)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coverageTags(title: String, buckets: [CoverageBucket]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if buckets.isEmpty {
                Text("-")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(buckets.map(bucketTitle).joined(separator: ", "))
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketTitle(_ bucket: CoverageBucket) -> String {
        switch bucket {
        case .latinExtended:
            return "LatinExt"
        case .cyrillic:
            return "Cyrillic"
        case .greek:
            return "Greek"
        case .cjk:
            return "CJK"
        }
    }

    private func formatSigned(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }

    private func formatSigned(_ value: Double) -> String {
        let rounded = Int(round(value))
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }
}

private enum CompareDisplayMode: String, CaseIterable, Identifiable {
    case sideBySide
    case overlay

    var id: String { rawValue }

    func title(_ tr: (L10nKey) -> String) -> String {
        switch self {
        case .sideBySide:
            tr(.compareModeSideBySide)
        case .overlay:
            tr(.compareModeOverlay)
        }
    }
}

private enum OverlayVisibility: String, CaseIterable, Identifiable {
    case both
    case baseline
    case candidate

    var id: String { rawValue }

    var showsBaseline: Bool {
        self == .both || self == .baseline
    }

    var showsCandidate: Bool {
        self == .both || self == .candidate
    }

    func title(_ tr: (L10nKey) -> String) -> String {
        switch self {
        case .both:
            tr(.compareOverlayBoth)
        case .baseline:
            tr(.compareOverlayBaselineOnly)
        case .candidate:
            tr(.compareOverlayCandidateOnly)
        }
    }
}

private struct CoverageDiff {
    let baselineOnly: [CoverageBucket]
    let candidateOnly: [CoverageBucket]
    let both: [CoverageBucket]

    init(baseline: ProgrammingProfile?, candidate: ProgrammingProfile?) {
        let left = baseline?.coverageBuckets ?? []
        let right = candidate?.coverageBuckets ?? []
        self.baselineOnly = left.subtracting(right).sortedByRawValue
        self.candidateOnly = right.subtracting(left).sortedByRawValue
        self.both = left.intersection(right).sortedByRawValue
    }
}

private extension Set where Element == CoverageBucket {
    var sortedByRawValue: [CoverageBucket] {
        sorted { $0.rawValue < $1.rawValue }
    }
}
