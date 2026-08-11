import Foundation

/// Owns programming-score weight state, preset mapping, and persistence.
/// Extracted from `FontBrowserViewModel` to keep the view model a thin
/// composition layer.
@MainActor
final class ProgrammingScorePreferencesController {
    private let preferencesController: FontBrowserPreferencesController

    /// Current weights. Mutated via `updateWeight` / `applyPreset`.
    private(set) var weights: ScoreWeights
    private(set) var preset: ScoreWeightPreset

    init(preferencesController: FontBrowserPreferencesController, restored: ScoreWeights?) {
        self.preferencesController = preferencesController
        if let restored {
            self.weights = restored
            self.preset = Self.bestMatchingPreset(for: restored)
        } else {
            self.weights = .default
            self.preset = .default
        }
    }

    func applyPreset(_ value: ScoreWeightPreset) {
        preset = value
        weights = value.weights
        persist()
    }

    func updateWeight(_ keyPath: WritableKeyPath<ScoreWeights, Double>, value: Double) {
        weights[keyPath: keyPath] = value
        preset = Self.bestMatchingPreset(for: weights)
        persist()
    }

    func persist() {
        preferencesController.saveScoreWeights(weights)
    }

    static func bestMatchingPreset(for weights: ScoreWeights) -> ScoreWeightPreset {
        if weights == ScoreWeightPreset.default.weights { return .default }
        if weights == ScoreWeightPreset.terminalHeavy.weights { return .terminalHeavy }
        if weights == ScoreWeightPreset.ideHeavy.weights { return .ideHeavy }
        if weights == ScoreWeightPreset.minimalist.weights { return .minimalist }
        return .default
    }
}
