import AppKit
import CoreText
import Foundation

protocol FontMetricsProbeProtocol: Sendable {
    func measure(postScriptName: String, isMonospaced: Bool) -> FontMetricsSample?
}

struct FontMetricsProbe: FontMetricsProbeProtocol {
    func measure(postScriptName: String, isMonospaced: Bool) -> FontMetricsSample? {
        guard isMonospaced else { return nil }
        let font = CTFontCreateWithName(postScriptName as CFString, 13, nil)
        let advances = asciiAdvances(for: font)
        let variance = asciiAdvanceVariance(for: advances)
        return FontMetricsSample(
            asciiAdvanceVariance: variance,
            uniformWidth: variance <= 0.5,
            confusableDistances: [:]
        )
    }

    func asciiAdvanceVariance(for advances: [Double]) -> Double {
        guard let minValue = advances.min(), let maxValue = advances.max() else { return 0 }
        return maxValue - minValue
    }

    private func asciiAdvances(for font: CTFont) -> [Double] {
        let chars = Array(32...126).compactMap(UnicodeScalar.init).map { UniChar($0.value) }
        var mutableChars = chars
        var glyphs = Array(repeating: CGGlyph(), count: mutableChars.count)
        let mapped = CTFontGetGlyphsForCharacters(font, &mutableChars, &glyphs, mutableChars.count)
        guard mapped else { return [] }

        var advances = Array(repeating: CGSize.zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        return advances.map { $0.width }
    }
}
