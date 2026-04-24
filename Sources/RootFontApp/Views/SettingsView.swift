import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FontBrowserViewModel

    var body: some View {
        Form {
            Picker(viewModel.tr(.language), selection: Binding(
                get: { viewModel.language },
                set: { viewModel.updateLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.radioGroup)

            Section(viewModel.tr(.programmingScoreWeights)) {
                Picker(viewModel.tr(.preset), selection: Binding(
                    get: { viewModel.scoreWeightPreset },
                    set: { viewModel.applyScoreWeightPreset($0) }
                )) {
                    Text(viewModel.tr(.presetDefault)).tag(ScoreWeightPreset.default)
                    Text(viewModel.tr(.presetTerminalHeavy)).tag(ScoreWeightPreset.terminalHeavy)
                    Text(viewModel.tr(.presetIDEHeavy)).tag(ScoreWeightPreset.ideHeavy)
                    Text(viewModel.tr(.presetMinimalist)).tag(ScoreWeightPreset.minimalist)
                }
                .pickerStyle(.menu)

                weightSlider(.weightMonospace, keyPath: \.monospaceBaseline)
                weightSlider(.weightDisambiguation, keyPath: \.glyphDisambiguation)
                weightSlider(.weightLigatures, keyPath: \.ligatureSupport)
                weightSlider(.weightStylisticSets, keyPath: \.stylisticFlexibility)
                weightSlider(.weightBoxDrawing, keyPath: \.boxDrawing)
                weightSlider(.weightPowerline, keyPath: \.powerlineGlyphs)
                weightSlider(.weightNerdFont, keyPath: \.nerdFontCoverage)
                weightSlider(.weightVariable, keyPath: \.variableFont)
                weightSlider(.weightLanguage, keyPath: \.languageCoverage)
                weightSlider(.weightVariety, keyPath: \.weightVariety)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func weightSlider(_ titleKey: L10nKey, keyPath: WritableKeyPath<ScoreWeights, Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.tr(titleKey))
                Spacer()
                Text(String(format: "%.0f", viewModel.scoreWeights[keyPath: keyPath]))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { viewModel.scoreWeights[keyPath: keyPath] },
                    set: { viewModel.updateScoreWeight(keyPath, value: $0) }
                ),
                in: 0...40,
                step: 1
            )
        }
    }
}
