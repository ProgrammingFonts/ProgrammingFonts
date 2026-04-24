import Foundation

struct FontFeaturePreferences: Codable, Hashable, Sendable {
    var ligaturesEnabled: Bool
    var zeroVariantEnabled: Bool
    var stylisticSetTags: Set<String>
}
