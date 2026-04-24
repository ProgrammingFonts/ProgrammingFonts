import Foundation

struct ProgrammingScoreEngine: Sendable {
    let weights: ScoreWeights

    init(weights: ScoreWeights = .default) {
        self.weights = weights
    }

    func score(item: FontItem, familyCoverage: FamilyWeightCoverage) -> ProgrammingScore? {
        guard let profile = item.programming, profile.isMonospaced else { return nil }

        let monospaceRaw = scoreMonospace(profile: profile, metrics: item.metrics)
        let glyphRaw = scoreGlyphDisambiguation(metrics: item.metrics)
        let ligatureRaw = profile.hasProgrammingLigatures ? 1.0 : 0.0
        let stylisticRaw = min(1.0, (Double(profile.availableStylisticSets.count) / 3.0) + (profile.hasZeroVariant ? 0.2 : 0))
        let boxRaw = profile.hasBoxDrawing ? 1.0 : 0.0
        let powerlineRaw = profile.hasPowerlineGlyphs ? 1.0 : 0.0
        let nerdRaw = profile.hasNerdFontGlyphs ? 1.0 : 0.0
        let variableRaw = profile.isVariableFont ? 1.0 : 0.0
        let languageRaw = min(1.0, Double(profile.coverageBuckets.count) / 4.0)
        let weightVarietyRaw = familyCoverage.hasWeightVariety(familyName: item.familyName) ? 1.0 : 0.0

        let breakdown: [FactorContribution] = [
            contribution(.monospaceBaseline, raw: monospaceRaw, weight: weights.monospaceBaseline),
            contribution(.glyphDisambiguation, raw: glyphRaw, weight: weights.glyphDisambiguation),
            contribution(.ligatureSupport, raw: ligatureRaw, weight: weights.ligatureSupport),
            contribution(.stylisticFlexibility, raw: stylisticRaw, weight: weights.stylisticFlexibility),
            contribution(.boxDrawing, raw: boxRaw, weight: weights.boxDrawing),
            contribution(.powerlineGlyphs, raw: powerlineRaw, weight: weights.powerlineGlyphs),
            contribution(.nerdFontCoverage, raw: nerdRaw, weight: weights.nerdFontCoverage),
            contribution(.variableFont, raw: variableRaw, weight: weights.variableFont),
            contribution(.languageCoverage, raw: languageRaw, weight: weights.languageCoverage),
            contribution(.weightVariety, raw: weightVarietyRaw, weight: weights.weightVariety)
        ]

        let total = Int(round(breakdown.reduce(0) { $0 + $1.weightedValue }))
        return ProgrammingScore(total: total, grade: grade(for: total), breakdown: breakdown)
    }

    private func contribution(_ factor: ProgrammingScoreFactor, raw: Double, weight: Double) -> FactorContribution {
        let normalized = max(0, min(1, raw))
        return FactorContribution(
            factor: factor,
            rawValue: normalized,
            weightedValue: normalized * weight,
            maxWeight: weight
        )
    }

    private func scoreMonospace(profile: ProgrammingProfile, metrics: FontMetricsSample?) -> Double {
        guard profile.isMonospaced else { return 0 }
        guard let metrics else { return 0.8 }
        if metrics.uniformWidth { return 1.0 }
        return max(0.0, 1.0 - min(1.0, metrics.asciiAdvanceVariance / 2.0))
    }

    private func scoreGlyphDisambiguation(metrics: FontMetricsSample?) -> Double {
        guard let metrics else { return 0.5 }
        if metrics.confusableDistances.isEmpty {
            return metrics.uniformWidth ? 0.7 : 0.4
        }
        let values = metrics.confusableDistances.values
        let avg = values.reduce(0, +) / Double(values.count)
        return max(0, min(1, avg))
    }

    private func grade(for total: Int) -> ProgrammingGrade {
        switch total {
        case 85...100: return .s
        case 70..<85: return .a
        case 55..<70: return .b
        case 40..<55: return .c
        default: return .notRecommended
        }
    }

    static func factorDeltas(
        baseline: ProgrammingScore,
        candidate: ProgrammingScore
    ) -> [FactorDelta] {
        let baselineMap = Dictionary(uniqueKeysWithValues: baseline.breakdown.map { ($0.factor, $0.weightedValue) })
        let candidateMap = Dictionary(uniqueKeysWithValues: candidate.breakdown.map { ($0.factor, $0.weightedValue) })
        return ProgrammingScoreFactor.allCases.map { factor in
            FactorDelta(
                factor: factor,
                baseline: baselineMap[factor] ?? 0,
                candidate: candidateMap[factor] ?? 0
            )
        }.sorted { lhs, rhs in
            abs(lhs.delta) > abs(rhs.delta)
        }
    }
}
