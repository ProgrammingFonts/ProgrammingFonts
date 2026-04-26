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
    @State private var overlayOpacity: Double = 0.58
    @State private var overlayVisibility: CompareOverlayVisibility = .both
    @State private var glyphSamplePreset: GlyphSamplePreset = .confusable
    @State private var glyphZoomScale: Double = 3.0
    @State private var showGlyphGrid = true
    @State private var outlineCharacter = "A"
    @State private var cachedOutlineKey = ""
    @State private var cachedBaselineBounds: CGRect?
    @State private var cachedCandidateBounds: CGRect?

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

            compareModeControls
            compareSurface

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

    @ViewBuilder
    private var compareSurface: some View {
        switch displayMode {
        case .sideBySide:
            HStack(alignment: .top, spacing: 10) {
                compareColumn(title: baseline.familyName, attributed: codeSnippet, font: baselineFont)
                compareColumn(title: candidate.familyName, attributed: codeSnippet, font: candidateFont)
            }
        case .overlay:
            overlayCompareBlock
        case .glyphZoom:
            glyphZoomCompareBlock
        case .outlineDiff:
            outlineDiffCompareBlock
        }
    }

    private var compareModeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(tr(.compareDisplayMode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("", selection: $displayMode) {
                    Text(tr(.compareModeSideBySide)).tag(CompareDisplayMode.sideBySide)
                    Text(tr(.compareModeOverlay)).tag(CompareDisplayMode.overlay)
                    Text(tr(.compareModeGlyphZoom)).tag(CompareDisplayMode.glyphZoom)
                    Text(tr(.compareModeOutlineDiff)).tag(CompareDisplayMode.outlineDiff)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if displayMode == .overlay {
                HStack(spacing: 8) {
                    Text(tr(.compareOverlayOpacity))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $overlayOpacity, in: 0.15...1)
                    Picker(tr(.compareOverlayVisibility), selection: $overlayVisibility) {
                        Text(tr(.compareOverlayBoth)).tag(CompareOverlayVisibility.both)
                        Text(tr(.compareOverlayBaselineOnly)).tag(CompareOverlayVisibility.baselineOnly)
                        Text(tr(.compareOverlayCandidateOnly)).tag(CompareOverlayVisibility.candidateOnly)
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 160)
                }
            } else if displayMode == .glyphZoom {
                HStack(spacing: 8) {
                    Text(tr(.glyphZoomPreset))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $glyphSamplePreset) {
                        Text(tr(.glyphZoomPresetConfusable)).tag(GlyphSamplePreset.confusable)
                        Text(tr(.glyphZoomPresetPunctuation)).tag(GlyphSamplePreset.punctuation)
                        Text(tr(.glyphZoomPresetFromSnippet)).tag(GlyphSamplePreset.fromSnippet)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Text(tr(.glyphZoomScale))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(value: $glyphZoomScale, in: 1.8...6)
                    Toggle(tr(.glyphZoomGrid), isOn: $showGlyphGrid)
                        .toggleStyle(.checkbox)
                        .font(.caption2)
                }
            } else if displayMode == .outlineDiff {
                HStack(spacing: 8) {
                    Text(tr(.outlineDiffCharacter))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("", text: $outlineCharacter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                }
            }
        }
    }

    private var overlayCompareBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr(.compareModeOverlay))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if overlayVisibility != .candidateOnly {
                    Text(codeSnippet)
                        .font(baselineFont)
                        .foregroundStyle(.blue.opacity(overlayOpacity))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if overlayVisibility != .baselineOnly {
                    Text(codeSnippet)
                        .font(candidateFont)
                        .foregroundStyle(.red.opacity(overlayOpacity))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .lineLimit(4)
            .padding(10)
            .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var glyphZoomCompareBlock: some View {
        let samples = CompareOverlaySupport.samples(for: glyphSamplePreset, snippet: String(codeSnippet.characters))
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr(.glyphZoomTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(samples, id: \.label) { sample in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sample.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ZStack {
                            if showGlyphGrid {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                            Text(sample.value)
                                .font(baselineFont)
                                .foregroundStyle(.blue.opacity(0.7))
                            Text(sample.value)
                                .font(candidateFont)
                                .foregroundStyle(.red.opacity(0.6))
                        }
                        .frame(height: 70)
                    }
                    .font(.system(size: 12 * glyphZoomScale))
                    .padding(8)
                    .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var outlineDiffCompareBlock: some View {
        let baselineBounds = cachedBaselineBounds
        let candidateBounds = cachedCandidateBounds
        let metrics = CompareOverlaySupport.outlineMetrics(
            baselineBounds: baselineBounds ?? .zero,
            candidateBounds: candidateBounds ?? .zero
        )
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr(.outlineDiffTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.opacity(0.75))
                HStack(spacing: 10) {
                    outlineRect(title: baseline.familyName, bounds: baselineBounds, tint: .blue)
                    outlineRect(title: candidate.familyName, bounds: candidateBounds, tint: .red)
                }
                .padding(10)
            }
            .frame(height: 130)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(tr(.outlineDiffOverlap)): \(Int(metrics.overlapRatio * 100))%")
                Text("\(tr(.outlineDiffShiftX)): \(formatSigned(metrics.horizontalShift))")
                Text("\(tr(.outlineDiffShiftY)): \(formatSigned(metrics.verticalShift))")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .onAppear {
            refreshOutlineCacheIfNeeded()
        }
        .onChange(of: outlineCharacter) { _, _ in
            refreshOutlineCacheIfNeeded()
        }
        .onChange(of: baseline.postScriptName) { _, _ in
            refreshOutlineCacheIfNeeded()
        }
        .onChange(of: candidate.postScriptName) { _, _ in
            refreshOutlineCacheIfNeeded()
        }
    }

    private func outlineRect(title: String, bounds: CGRect?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .lineLimit(1)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
                if let bounds {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(tint.opacity(0.85), lineWidth: 2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    Text("w:\(Int(bounds.width)) h:\(Int(bounds.height))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("-")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 70)
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

    private func glyphBounds(for text: String, postScriptName: String) -> CGRect? {
        CompareOverlaySupport.glyphBounds(for: text, postScriptName: postScriptName)
    }

    private func refreshOutlineCacheIfNeeded() {
        let glyph = String(outlineCharacter.prefix(1))
        let key = "\(glyph)#\(baseline.postScriptName)#\(candidate.postScriptName)"
        guard key != cachedOutlineKey else { return }
        cachedOutlineKey = key
        cachedBaselineBounds = glyphBounds(for: glyph, postScriptName: baseline.postScriptName)
        cachedCandidateBounds = glyphBounds(for: glyph, postScriptName: candidate.postScriptName)
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
