import AppKit
import CoreText
import Foundation

struct OpenTypeFeatureOptions: Sendable {
    var ligaturesEnabled: Bool
    var zeroVariantEnabled: Bool
    var stylisticSetTags: Set<String>
}

protocol OpenTypeFeatureBinding: Sendable {
    func bind(base: NSFont, options: OpenTypeFeatureOptions) -> NSFont
}

struct OpenTypeFeatureBinder: OpenTypeFeatureBinding {
    func bind(base: NSFont, options: OpenTypeFeatureOptions) -> NSFont {
        var settings: [[CFString: Int]] = []
        settings.append([
            kCTFontFeatureTypeIdentifierKey: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey: options.ligaturesEnabled
                ? kCommonLigaturesOnSelector
                : kCommonLigaturesOffSelector
        ])
        let ctBase = CTFontCreateWithName(base.fontName as CFString, base.pointSize, nil)
        let discovered = discoverFeatureSelectors(for: ctBase)
        if let zero = discovered.zeroSelector, options.zeroVariantEnabled {
            settings.append([
                kCTFontFeatureTypeIdentifierKey: zero.typeIdentifier,
                kCTFontFeatureSelectorIdentifierKey: zero.selectorIdentifier
            ])
        }
        for setTag in options.stylisticSetTags {
            if let selector = discovered.stylisticSetSelectors[setTag.lowercased()] {
                settings.append([
                    kCTFontFeatureTypeIdentifierKey: selector.typeIdentifier,
                    kCTFontFeatureSelectorIdentifierKey: selector.selectorIdentifier
                ])
            }
        }

        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: base.fontName,
            kCTFontSizeAttribute: base.pointSize,
            kCTFontFeatureSettingsAttribute: settings
        ] as CFDictionary)
        let derived = CTFontCreateWithFontDescriptor(descriptor, base.pointSize, nil)
        return NSFont(descriptor: CTFontCopyFontDescriptor(derived) as NSFontDescriptor, size: base.pointSize)
            ?? NSFont(name: CTFontCopyPostScriptName(ctBase) as String, size: base.pointSize)
            ?? base
    }

    private func discoverFeatureSelectors(for font: CTFont) -> DiscoveredSelectors {
        guard let features = CTFontCopyFeatures(font) as? [[CFString: Any]] else {
            return DiscoveredSelectors(zeroSelector: nil, stylisticSetSelectors: [:])
        }
        var zeroSelector: FeatureSelector?
        var stylistic: [String: FeatureSelector] = [:]

        for feature in features {
            guard let typeIdentifier = (feature[kCTFontFeatureTypeIdentifierKey] as? NSNumber)?.intValue else { continue }
            let selectors = feature[kCTFontFeatureTypeSelectorsKey] as? [[CFString: Any]] ?? []
            for selector in selectors {
                guard let selectorIdentifier = (selector[kCTFontFeatureSelectorIdentifierKey] as? NSNumber)?.intValue else {
                    continue
                }
                let name = (selector[kCTFontFeatureSelectorNameKey] as? String ?? "").lowercased()
                if name.contains("slashed zero") || name.contains("dotted zero") {
                    zeroSelector = FeatureSelector(typeIdentifier: typeIdentifier, selectorIdentifier: selectorIdentifier)
                }
                if let tag = stylisticTag(from: name) {
                    stylistic[tag] = FeatureSelector(typeIdentifier: typeIdentifier, selectorIdentifier: selectorIdentifier)
                }
            }
        }
        return DiscoveredSelectors(zeroSelector: zeroSelector, stylisticSetSelectors: stylistic)
    }

    private func stylisticTag(from lowerName: String) -> String? {
        if let match = lowerName.range(of: #"ss\d{2}"#, options: .regularExpression) {
            return String(lowerName[match])
        }
        if let match = lowerName.range(of: #"set\s*(\d{1,2})"#, options: .regularExpression) {
            let digits = String(lowerName[match]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let number = Int(digits), (1...99).contains(number) {
                return String(format: "ss%02d", number)
            }
        }
        return nil
    }
}

private struct FeatureSelector: Sendable {
    let typeIdentifier: Int
    let selectorIdentifier: Int
}

private struct DiscoveredSelectors: Sendable {
    let zeroSelector: FeatureSelector?
    let stylisticSetSelectors: [String: FeatureSelector]
}
