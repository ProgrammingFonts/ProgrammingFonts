import Foundation

enum AppMetadata {
    static let appName = "RootFont"
    static let websiteURL = "https://rootfont.com"
    static let githubURL = "https://github.com/rootfont/rootfont"
    static let fallbackVersion = "0.2.0-alpha"
    static let fallbackBuild = "3"

    private struct VersionConfig: Decodable {
        let shortVersion: String
        let buildNumber: String
    }

    private static let bundledVersionConfig: VersionConfig? = {
        guard let url = Bundle.module.url(forResource: "AppVersion", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(VersionConfig.self, from: data)
    }()

    static var shortVersion: String {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !plistValue.isEmpty {
            return plistValue
        }
        if let configValue = bundledVersionConfig?.shortVersion, !configValue.isEmpty {
            return configValue
        }
        return fallbackVersion
    }

    static var buildNumber: String {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !plistValue.isEmpty {
            return plistValue
        }
        if let configValue = bundledVersionConfig?.buildNumber, !configValue.isEmpty {
            return configValue
        }
        return fallbackBuild
    }

    static var semanticVersionDisplay: String {
        "v\(shortVersion)"
    }

    static var buildDisplay: String {
        "Build \(buildNumber)"
    }

    static var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "Copyright © \(year) RootFont"
    }
}
