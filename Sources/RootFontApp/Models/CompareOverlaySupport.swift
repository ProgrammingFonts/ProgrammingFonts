import CoreText
import CoreGraphics
import Foundation

enum CompareDisplayMode: String, CaseIterable, Identifiable {
    case sideBySide
    case overlay
    case glyphZoom
    case outlineDiff

    var id: Self { self }
}

enum CompareOverlayVisibility: String, CaseIterable, Identifiable {
    case both
    case baselineOnly
    case candidateOnly

    var id: Self { self }
}

enum GlyphSamplePreset: String, CaseIterable, Identifiable {
    case confusable
    case punctuation
    case fromSnippet

    var id: Self { self }
}

struct GlyphSample: Equatable {
    let label: String
    let value: String
}

struct OutlineDiffMetrics {
    let overlapRatio: Double
    let horizontalShift: Double
    let verticalShift: Double
}

enum CompareOverlaySupport {
    private static let confusableSamples: [GlyphSample] = [
        GlyphSample(label: "Il1", value: "Il1"),
        GlyphSample(label: "O0", value: "O0"),
        GlyphSample(label: "rn/m", value: "rnm"),
        GlyphSample(label: "B8", value: "B8")
    ]

    private static let punctuationSamples: [GlyphSample] = [
        GlyphSample(label: "{}[]()", value: "{}[]()"),
        GlyphSample(label: ",.;:", value: ",.;:"),
        GlyphSample(label: "<=>", value: "<=>"),
        GlyphSample(label: "|/\\", value: "|/\\")
    ]

    static func samples(for preset: GlyphSamplePreset, snippet: String) -> [GlyphSample] {
        switch preset {
        case .confusable:
            return confusableSamples
        case .punctuation:
            return punctuationSamples
        case .fromSnippet:
            let extracted = extractTokens(from: snippet).prefix(6).map { token in
                GlyphSample(label: token, value: token)
            }
            return extracted.isEmpty ? confusableSamples : Array(extracted)
        }
    }

    static func outlineMetrics(baselineBounds: CGRect, candidateBounds: CGRect) -> OutlineDiffMetrics {
        let intersection = baselineBounds.intersection(candidateBounds)
        let overlapArea = max(0, intersection.width) * max(0, intersection.height)
        let baselineArea = max(0, baselineBounds.width * baselineBounds.height)
        let candidateArea = max(0, candidateBounds.width * candidateBounds.height)
        let unionArea = max(1, baselineArea + candidateArea - overlapArea)
        return OutlineDiffMetrics(
            overlapRatio: overlapArea / unionArea,
            horizontalShift: candidateBounds.midX - baselineBounds.midX,
            verticalShift: candidateBounds.midY - baselineBounds.midY
        )
    }

    static func glyphBounds(for text: String, postScriptName: String, pointSize: CGFloat = 64) -> CGRect? {
        guard let scalar = text.unicodeScalars.first else { return nil }
        let ctFont = CTFontCreateWithName(postScriptName as CFString, pointSize, nil)
        var code = UniChar(scalar.value)
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(ctFont, &code, &glyph, 1),
              let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
            return nil
        }

        return path.boundingBox
    }

    private static func extractTokens(from snippet: String) -> [String] {
        snippet
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }
            .filter { token in
                token.count >= 2 && token.count <= 6
            }
    }
}
