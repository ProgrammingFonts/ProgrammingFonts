import Foundation

enum AppMetadata {
    static let appName = "RootFont"
    static let slogan = "The native font manager for designers and programmers"
    static let websiteURL = "https://github.com/rootfont/rootfont"
    static let fallbackVersion = "0.1.0"
    static let fallbackBuild = "1"

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? fallbackBuild
    }

    static var semanticVersionDisplay: String {
        "v\(shortVersion)(\(buildNumber))"
    }

    static var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Copyright © \(year) RootFont"
    }
}
