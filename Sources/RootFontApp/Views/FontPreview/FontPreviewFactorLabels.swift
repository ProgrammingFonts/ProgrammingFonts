import Foundation

struct FontPreviewFactorLabels {
    let tr: (L10nKey) -> String

    func title(_ factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline: return tr(.factorMonospaceBaseline)
        case .glyphDisambiguation: return tr(.factorGlyphDisambiguation)
        case .ligatureSupport: return tr(.factorLigatureSupport)
        case .stylisticFlexibility: return tr(.factorStylisticFlexibility)
        case .boxDrawing: return tr(.factorBoxDrawing)
        case .powerlineGlyphs: return tr(.factorPowerlineGlyphs)
        case .nerdFontCoverage: return tr(.factorNerdFontCoverage)
        case .variableFont: return tr(.factorVariableFont)
        case .languageCoverage: return tr(.factorLanguageCoverage)
        case .weightVariety: return tr(.factorWeightVariety)
        }
    }

    func hint(_ factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline: return tr(.factorHintMonospaceBaseline)
        case .glyphDisambiguation: return tr(.factorHintGlyphDisambiguation)
        case .ligatureSupport: return tr(.factorHintLigatureSupport)
        case .stylisticFlexibility: return tr(.factorHintStylisticFlexibility)
        case .boxDrawing: return tr(.factorHintBoxDrawing)
        case .powerlineGlyphs: return tr(.factorHintPowerlineGlyphs)
        case .nerdFontCoverage: return tr(.factorHintNerdFontCoverage)
        case .variableFont: return tr(.factorHintVariableFont)
        case .languageCoverage: return tr(.factorHintLanguageCoverage)
        case .weightVariety: return tr(.factorHintWeightVariety)
        }
    }

    func whyDescription(_ factor: ProgrammingScoreFactor) -> String {
        switch factor {
        case .monospaceBaseline: return tr(.factorWhyMonospaceBaseline)
        case .glyphDisambiguation: return tr(.factorWhyGlyphDisambiguation)
        case .ligatureSupport: return tr(.factorWhyLigatureSupport)
        case .stylisticFlexibility: return tr(.factorWhyStylisticFlexibility)
        case .boxDrawing: return tr(.factorWhyBoxDrawing)
        case .powerlineGlyphs: return tr(.factorWhyPowerlineGlyphs)
        case .nerdFontCoverage: return tr(.factorWhyNerdFontCoverage)
        case .variableFont: return tr(.factorWhyVariableFont)
        case .languageCoverage: return tr(.factorWhyLanguageCoverage)
        case .weightVariety: return tr(.factorWhyWeightVariety)
        }
    }

    func whyExample(_ factor: ProgrammingScoreFactor) -> String {
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

    func whyTitle(_ factor: ProgrammingScoreFactor) -> String {
        title(factor)
    }

    func bucketTitle(_ bucket: CoverageBucket) -> String {
        switch bucket {
        case .latinExtended: return tr(.coverageBucketLatinExtended)
        case .cyrillic: return tr(.coverageBucketCyrillic)
        case .greek: return tr(.coverageBucketGreek)
        case .cjk: return tr(.coverageBucketCJK)
        }
    }
}
