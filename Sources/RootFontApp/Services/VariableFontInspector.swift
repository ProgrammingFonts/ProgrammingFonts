import AppKit
import CoreText
import Foundation

struct VariableFontAxis: Identifiable, Hashable, Sendable {
    let tag: String
    let name: String
    let minValue: Double
    let maxValue: Double
    let defaultValue: Double

    var id: String { tag }
}

enum VariableFontInspector: Sendable {
    static func axes(postScriptName: String, size: CGFloat = 16) -> [VariableFontAxis] {
        guard let base = NSFont(name: postScriptName, size: size) else { return [] }
        let ctFont = base as CTFont
        guard let rawAxes = CTFontCopyVariationAxes(ctFont) as? [[CFString: Any]] else {
            return []
        }

        return rawAxes.compactMap { axis in
            guard let tagNumber = axis[kCTFontVariationAxisIdentifierKey] as? NSNumber else {
                return nil
            }
            let tag = variationTagString(tagNumber.intValue)
            let name = axis[kCTFontVariationAxisNameKey] as? String ?? tag
            let minValue = (axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue ?? 0
            let maxValue = (axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue ?? 0
            let defaultValue = (axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue ?? minValue
            return VariableFontAxis(
                tag: tag,
                name: name,
                minValue: minValue,
                maxValue: maxValue,
                defaultValue: defaultValue
            )
        }
    }

    static func font(
        postScriptName: String,
        size: CGFloat,
        axisValues: [String: Double]
    ) -> NSFont? {
        guard let base = NSFont(name: postScriptName, size: size) else { return nil }
        let ctFont = base as CTFont
        var variation: [NSNumber: NSNumber] = [:]
        for (tag, value) in axisValues {
            variation[NSNumber(value: variationTagInt(tag))] = NSNumber(value: value)
        }
        guard !variation.isEmpty else { return base }
        let descriptor = CTFontCopyFontDescriptor(ctFont)
        let attributes = [kCTFontVariationAttribute: variation] as CFDictionary
        let variedDescriptor = CTFontDescriptorCreateCopyWithAttributes(descriptor, attributes)
        let derived = CTFontCreateWithFontDescriptor(variedDescriptor, size, nil)
        return derived as NSFont
    }

    private static func variationTagInt(_ tag: String) -> UInt32 {
        guard tag.count == 4 else { return 0 }
        var value: UInt32 = 0
        for scalar in tag.unicodeScalars.prefix(4) {
            value = (value << 8) | UInt32(scalar.value)
        }
        return value
    }

    private static func variationTagString(_ identifier: Int) -> String {
        let value = UInt32(bitPattern: Int32(identifier))
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? "axis"
    }
}
