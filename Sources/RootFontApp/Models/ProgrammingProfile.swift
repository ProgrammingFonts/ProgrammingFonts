import Foundation

struct StylisticSet: Hashable, Codable, Sendable {
    let tag: String
    let name: String
}

enum CoverageBucket: String, CaseIterable, Codable, Sendable {
    case latinExtended
    case cyrillic
    case greek
    case cjk
}

struct ProgrammingProfile: Hashable, Codable, Sendable {
    var isMonospaced: Bool
    var hasProgrammingLigatures: Bool
    var availableStylisticSets: [StylisticSet]
    var hasZeroVariant: Bool
    var hasPowerlineGlyphs: Bool
    var hasNerdFontGlyphs: Bool
    var hasBoxDrawing: Bool
    var coverageBuckets: Set<CoverageBucket>
    var isVariableFont: Bool

    static let empty = ProgrammingProfile(
        isMonospaced: false,
        hasProgrammingLigatures: false,
        availableStylisticSets: [],
        hasZeroVariant: false,
        hasPowerlineGlyphs: false,
        hasNerdFontGlyphs: false,
        hasBoxDrawing: false,
        coverageBuckets: [],
        isVariableFont: false
    )
}

enum ConfusablePair: String, CaseIterable, Codable, Sendable, Hashable {
    case iL1 = "Il1|"
    case o0 = "O0"
    case rnm = "rnm"
    case b8 = "8B"
    case s5 = "5S"
    case g9q = "9gq"
}

struct FontMetricsSample: Hashable, Codable, Sendable {
    var asciiAdvanceVariance: Double
    var uniformWidth: Bool
    var confusableDistances: [ConfusablePair: Double]
}

enum ProgrammingGrade: String, Codable, Sendable {
    case s
    case a
    case b
    case c
    case notRecommended
}

enum ProgrammingScoreFactor: String, Codable, Sendable, Hashable, CaseIterable {
    case monospaceBaseline
    case glyphDisambiguation
    case ligatureSupport
    case stylisticFlexibility
    case boxDrawing
    case powerlineGlyphs
    case nerdFontCoverage
    case variableFont
    case languageCoverage
    case weightVariety
}

struct FactorContribution: Hashable, Codable, Sendable {
    var factor: ProgrammingScoreFactor
    var rawValue: Double
    var weightedValue: Double
    var maxWeight: Double
}

struct ProgrammingScore: Hashable, Codable, Sendable {
    var total: Int
    var grade: ProgrammingGrade
    var breakdown: [FactorContribution]
}

struct FactorDelta: Hashable, Sendable {
    var factor: ProgrammingScoreFactor
    var baseline: Double
    var candidate: Double

    var delta: Double { candidate - baseline }
}

struct ScoreWeights: Hashable, Codable, Sendable {
    var monospaceBaseline: Double = 30
    var glyphDisambiguation: Double = 20
    var ligatureSupport: Double = 10
    var stylisticFlexibility: Double = 8
    var boxDrawing: Double = 8
    var powerlineGlyphs: Double = 5
    var nerdFontCoverage: Double = 5
    var variableFont: Double = 4
    var languageCoverage: Double = 5
    var weightVariety: Double = 5

    static let `default` = ScoreWeights()

    static let terminalHeavy = ScoreWeights(
        monospaceBaseline: 28,
        glyphDisambiguation: 16,
        ligatureSupport: 8,
        stylisticFlexibility: 6,
        boxDrawing: 12,
        powerlineGlyphs: 10,
        nerdFontCoverage: 10,
        variableFont: 2,
        languageCoverage: 4,
        weightVariety: 4
    )

    static let ideHeavy = ScoreWeights(
        monospaceBaseline: 28,
        glyphDisambiguation: 18,
        ligatureSupport: 14,
        stylisticFlexibility: 12,
        boxDrawing: 6,
        powerlineGlyphs: 3,
        nerdFontCoverage: 3,
        variableFont: 5,
        languageCoverage: 6,
        weightVariety: 5
    )

    static let minimalist = ScoreWeights(
        monospaceBaseline: 38,
        glyphDisambiguation: 30,
        ligatureSupport: 8,
        stylisticFlexibility: 8,
        boxDrawing: 8,
        powerlineGlyphs: 0,
        nerdFontCoverage: 0,
        variableFont: 2,
        languageCoverage: 4,
        weightVariety: 2
    )
}

enum ScoreWeightPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case `default`
    case terminalHeavy
    case ideHeavy
    case minimalist

    var id: Self { self }

    var weights: ScoreWeights {
        switch self {
        case .default: return .default
        case .terminalHeavy: return .terminalHeavy
        case .ideHeavy: return .ideHeavy
        case .minimalist: return .minimalist
        }
    }
}
