import Foundation

/// User-facing errors raised by services. The raw case carries an
/// `L10nKey` so the view layer can localize the message without the
/// service needing to depend on the current `AppLanguage`.
enum AppError: Error, Sendable, Equatable {
    case catalogReadFailed
    case importNoSupportedFonts
    case managedFontRecoveryFailed
    case activationConflict(path: String)
    case activationFailed(reason: String)
    case fontBookOpenFailed
    case loadFailed
    case invalidFontFile(path: String)
    case fontNotFound
    case rollbackFailed(primary: String, cleanup: [String])

    var localizedKey: L10nKey {
        switch self {
        case .catalogReadFailed: return .catalogReadFailed
        case .importNoSupportedFonts: return .importNoSupportedFonts
        case .managedFontRecoveryFailed: return .managedFontRecoveryFailed
        case .activationConflict: return .activationConflict
        case .activationFailed: return .activationFailed
        case .fontBookOpenFailed: return .fontBookOpenFailed
        case .loadFailed: return .loadFailed
        case .invalidFontFile: return .loadFailed
        case .fontNotFound: return .loadFailed
        case .rollbackFailed: return .activationFailed
        }
    }

    /// Optional detail string to interpolate into the localized message.
    /// `nil` means use the key as-is.
    var detail: String? {
        switch self {
        case .activationConflict(let path): return path
        case .activationFailed(let reason): return reason
        case .invalidFontFile(let path): return path
        case .rollbackFailed(let primary, let cleanup):
            return "\(primary) | cleanup: \(cleanup.joined(separator: "; "))"
        default: return nil
        }
    }
}
