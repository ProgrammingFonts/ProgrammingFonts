import AppKit
import Foundation

enum WeightTier: String, CaseIterable, Codable, Sendable {
    case thin
    case regular
    case medium
    case bold
    case black
}

protocol FontWeightTierResolving: Sendable {
    func resolveWeightTier(postScriptName: String) -> WeightTier
}

struct FontWeightTierResolver: FontWeightTierResolving {
    func resolveWeightTier(postScriptName: String) -> WeightTier {
        guard let font = NSFont(name: postScriptName, size: 13) else {
            return .regular
        }
        let weight = NSFontManager.shared.weight(of: font)
        switch weight {
        case ..<4:
            return .thin
        case 4...6:
            return .regular
        case 7:
            return .medium
        case 8...10:
            return .bold
        default:
            return .black
        }
    }
}

struct FamilyWeightCoverage: Sendable {
    let buckets: [String: Set<WeightTier>]

    static func build(
        from fonts: [FontItem],
        resolver: FontWeightTierResolving = FontWeightTierResolver()
    ) -> FamilyWeightCoverage {
        var map: [String: Set<WeightTier>] = [:]
        for item in fonts {
            let familyKey = item.familyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !familyKey.isEmpty else { continue }
            let tier = resolver.resolveWeightTier(postScriptName: item.postScriptName)
            map[familyKey, default: []].insert(tier)
        }
        return FamilyWeightCoverage(buckets: map)
    }

    func tiers(forFamilyName familyName: String) -> Set<WeightTier> {
        buckets[familyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? []
    }

    func hasWeightVariety(familyName: String) -> Bool {
        tiers(forFamilyName: familyName).count >= 3
    }
}
