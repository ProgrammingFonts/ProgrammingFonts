import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum AppMetadata {
    static let appName = "RootFont"
    static let websiteURL = "https://rootfont.com"
    static let githubURL = "https://github.com/rootfont/rootfont"
    static let fallbackVersion = "0.2.0-alpha"
    static let fallbackBuild = "3"

    private struct VersionConfig: Decodable {
        let shortVersion: String
        let buildNumber: String
        let commitSha: String?
    }

    private static let commitShaPlistKey = "RootFontCommitSha"

    private static let bundledVersionConfig: VersionConfig? = {
        guard let url = Bundle.module.url(forResource: "AppVersion", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(VersionConfig.self, from: data)
    }()

    static var shortVersion: String {
        if let configValue = bundledVersionConfig?.shortVersion, !configValue.isEmpty {
            return configValue
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !plistValue.isEmpty {
            return plistValue
        }
        return fallbackVersion
    }

    static var buildNumber: String {
        if let configValue = bundledVersionConfig?.buildNumber, !configValue.isEmpty {
            return configValue
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !plistValue.isEmpty {
            return plistValue
        }
        return fallbackBuild
    }

    static var semanticVersionDisplay: String {
        "v\(shortVersion)"
    }

    static var buildDisplay: String {
        "Build \(buildNumber)"
    }

    static var combinedVersionDisplay: String {
        "v\(shortVersion) (\(buildNumber))"
    }

    /// Short git SHA embedded at build time. Empty when running via
    /// `swift run` without the build script.
    static var commitShortSHA: String {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: commitShaPlistKey) as? String,
           !plistValue.isEmpty {
            return plistValue
        }
        if let configValue = bundledVersionConfig?.commitSha, !configValue.isEmpty {
            return configValue
        }
        return ""
    }

    /// One-line string suitable for bug reports, e.g.
    /// `RootFont v0.2.0-alpha (3) · commit abc1234`.
    static var diagnosticsLine: String {
        var parts = ["\(appName) v\(shortVersion) (\(buildNumber))"]
        let sha = commitShortSHA
        if !sha.isEmpty {
            parts.append("commit \(sha)")
        }
        return parts.joined(separator: " · ")
    }

    /// Host OS + user locale + appearance trait, joined with ` · `.
    /// Designed for pasting into bug reports.
    static func systemInfoLine(appearance: AppAppearanceMode, language: AppLanguage) -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let appearanceLabel = appearanceDescription(appearance)
        let languageLabel = language.rawValue
        let architecture: String
        #if arch(arm64)
        architecture = "arm64"
        #elseif arch(x86_64)
        architecture = "x86_64"
        #else
        architecture = "unknown"
        #endif
        return [osString, architecture, languageLabel, appearanceLabel].joined(separator: " · ")
    }

    private static func appearanceDescription(_ mode: AppAppearanceMode) -> String {
        switch mode {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        }
    }

    static var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Copyright © \(year) RootFont"
    }
}
