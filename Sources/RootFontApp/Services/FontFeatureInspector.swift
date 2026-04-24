import AppKit
import CoreText
import Foundation

protocol FontFeatureInspectorProtocol: Sendable {
    func inspect(postScriptName: String) -> ProgrammingProfile
}

struct FontFeatureInspector: FontFeatureInspectorProtocol {
    func inspect(postScriptName: String) -> ProgrammingProfile {
        let ctFont = CTFontCreateWithName(postScriptName as CFString, 16, nil)
        return inspect(font: ctFont)
    }

    func inspect(font: CTFont) -> ProgrammingProfile {
        let traits = CTFontGetSymbolicTraits(font)
        let isMonospaced = traits.contains(.traitMonoSpace)
        let isVariableFont = (CTFontCopyVariationAxes(font) as? [[CFString: Any]])?.isEmpty == false

        let featureMeta = featureMetadata(for: font)
        let featureTags = Set(featureMeta.compactMap(\.tag))
        let featureNames = featureMeta.map(\.name)

        let characterSet = CTFontCopyCharacterSet(font) as CharacterSet
        return ProgrammingProfile(
            isMonospaced: isMonospaced,
            hasProgrammingLigatures: detectProgrammingLigatures(featureTags: featureTags),
            availableStylisticSets: stylisticSets(from: featureMeta),
            hasZeroVariant: detectZeroVariant(featureNames: featureNames),
            hasPowerlineGlyphs: hasCoverage(in: characterSet, range: 0xE0A0...0xE0B3),
            hasNerdFontGlyphs: hasNerdCoverage(in: characterSet),
            hasBoxDrawing: hasCoverage(in: characterSet, range: 0x2500...0x257F),
            coverageBuckets: coverageBuckets(for: characterSet),
            isVariableFont: isVariableFont
        )
    }

    func detectProgrammingLigatures(featureTags: Set<String>) -> Bool {
        let normalized = Set(featureTags.map { $0.lowercased() })
        return !normalized.intersection(["liga", "calt", "dlig"]).isEmpty
    }

    func detectZeroVariant(featureNames: [String]) -> Bool {
        featureNames.contains { name in
            let lower = name.lowercased()
            return lower.contains("slashed zero") || lower.contains("dotted zero") || lower.contains("zero")
        }
    }

    func coverageBuckets(for set: CharacterSet) -> Set<CoverageBucket> {
        var buckets = Set<CoverageBucket>()
        if hasCoverage(in: set, range: 0x0100...0x024F) {
            buckets.insert(.latinExtended)
        }
        if hasCoverage(in: set, range: 0x0400...0x04FF) {
            buckets.insert(.cyrillic)
        }
        if hasCoverage(in: set, range: 0x0370...0x03FF) {
            buckets.insert(.greek)
        }
        if hasCoverage(in: set, range: 0x4E00...0x9FFF) {
            buckets.insert(.cjk)
        }
        return buckets
    }

    private func hasNerdCoverage(in set: CharacterSet) -> Bool {
        hasCoverage(in: set, range: 0xE5FA...0xE62B) || hasCoverage(in: set, range: 0xF000...0xF2FF)
    }

    private func hasCoverage(in set: CharacterSet, range: ClosedRange<UInt32>) -> Bool {
        for scalar in range {
            guard let unicode = UnicodeScalar(scalar) else { continue }
            if set.contains(unicode) {
                return true
            }
        }
        return false
    }

    private func stylisticSets(from entries: [FeatureMeta]) -> [StylisticSet] {
        entries.compactMap { entry in
            guard let tag = entry.tag?.lowercased(), tag.hasPrefix("ss") else { return nil }
            return StylisticSet(tag: tag, name: entry.name)
        }
    }

    private func featureMetadata(for font: CTFont) -> [FeatureMeta] {
        guard let features = CTFontCopyFeatures(font) as? [[CFString: Any]] else {
            return []
        }

        var results: [FeatureMeta] = []
        for feature in features {
            let typeName = feature[kCTFontFeatureTypeNameKey] as? String ?? ""
            let selectors = feature[kCTFontFeatureTypeSelectorsKey] as? [[CFString: Any]] ?? []
            if selectors.isEmpty {
                results.append(FeatureMeta(tag: nil, name: typeName))
                continue
            }
            for selector in selectors {
                let selectorName = selector[kCTFontFeatureSelectorNameKey] as? String ?? typeName
                let selectorIdentifier = selector[kCTFontFeatureSelectorIdentifierKey] as? NSNumber
                let tag = tagFromSelectorName(selectorName, identifier: selectorIdentifier?.intValue)
                results.append(FeatureMeta(tag: tag, name: selectorName))
            }
        }
        return results
    }

    private func tagFromSelectorName(_ name: String, identifier: Int?) -> String? {
        let lower = name.lowercased()
        if lower.contains("ligature") { return "liga" }
        if lower.contains("contextual") { return "calt" }
        if lower.contains("discretionary") { return "dlig" }
        if lower.contains("slashed zero") || lower.contains("dotted zero") { return "zero" }
        if let identifier, (1...20).contains(identifier) {
            return String(format: "ss%02d", identifier)
        }
        if let match = lower.range(of: #"ss\d{2}"#, options: .regularExpression) {
            return String(lower[match])
        }
        return nil
    }
}

private struct FeatureMeta {
    let tag: String?
    let name: String
}
