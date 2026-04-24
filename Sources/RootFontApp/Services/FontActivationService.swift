import CoreText
import Foundation

enum FontActivationScope: String, Codable, Sendable {
    case process
    case user
}

enum FontActivationError: Error, Sendable {
    case fontNotFound
    case installConflict(destination: URL)
}

struct ActivatedFontEntry: Codable, Hashable, Sendable {
    var fontID: String
    var originalURL: URL
    var installedURL: URL?
    var scope: FontActivationScope
}

protocol FontActivationServiceProtocol: Sendable {
    func activateForProcess(fontID: String) throws
    func installForUser(fontID: String) throws
    func uninstall(fontID: String) throws
    func reconcile() throws
    func isManaged(fontID: String) -> Bool
    func managedCount() -> Int
    func managedFontIDs() -> Set<String>
    func managedFontsDirectoryURL() -> URL
}

struct FontActivationService: FontActivationServiceProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let appSupportManifestURL: URL
    private let userInstallDirectoryURL: URL
    private let availableFontURLsProvider: @Sendable () -> [URL]
    private let registerAction: @Sendable ([URL], CTFontManagerScope) throws -> Void
    private let unregisterAction: @Sendable ([URL], CTFontManagerScope) throws -> Void

    init(
        fileManager: FileManager = .default,
        manifestURL: URL? = nil,
        userInstallDirectoryURL: URL? = nil,
        availableFontURLsProvider: (@Sendable () -> [URL])? = nil,
        registerAction: (@Sendable ([URL], CTFontManagerScope) throws -> Void)? = nil,
        unregisterAction: (@Sendable ([URL], CTFontManagerScope) throws -> Void)? = nil
    ) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.appSupportManifestURL = manifestURL ?? appSupport
            .appendingPathComponent("RootFont", isDirectory: true)
            .appendingPathComponent("activated-fonts.json")
        self.userInstallDirectoryURL = userInstallDirectoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Fonts/RootFont", isDirectory: true)
        self.availableFontURLsProvider = availableFontURLsProvider ?? {
            (CTFontManagerCopyAvailableFontURLs() as? [URL]) ?? []
        }
        self.registerAction = registerAction ?? { urls, scope in
            try Self.defaultRegister(urls: urls, scope: scope)
        }
        self.unregisterAction = unregisterAction ?? { urls, scope in
            try Self.defaultUnregister(urls: urls, scope: scope)
        }
    }

    func activateForProcess(fontID: String) throws {
        let url = try resolveURL(for: fontID)
        try register(urls: [url], scope: .process)
        var manifest = loadManifest()
        manifest[fontID] = ActivatedFontEntry(
            fontID: fontID,
            originalURL: url,
            installedURL: nil,
            scope: .process
        )
        saveManifest(manifest)
    }

    func installForUser(fontID: String) throws {
        let original = try resolveURL(for: fontID)
        try fileManager.createDirectory(at: userInstallDirectoryURL, withIntermediateDirectories: true)
        let destination = userInstallDirectoryURL.appendingPathComponent(original.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            throw FontActivationError.installConflict(destination: destination)
        }
        try fileManager.copyItem(at: original, to: destination)
        try register(urls: [destination], scope: .user)
        var manifest = loadManifest()
        manifest[fontID] = ActivatedFontEntry(
            fontID: fontID,
            originalURL: original,
            installedURL: destination,
            scope: .user
        )
        saveManifest(manifest)
    }

    func uninstall(fontID: String) throws {
        var manifest = loadManifest()
        guard let entry = manifest[fontID] else { return }
        if let installed = entry.installedURL {
            try? unregister(urls: [installed], scope: .user)
            if fileManager.fileExists(atPath: installed.path) {
                try? fileManager.removeItem(at: installed)
            }
        } else {
            try? unregister(urls: [entry.originalURL], scope: .process)
        }
        manifest.removeValue(forKey: fontID)
        saveManifest(manifest)
    }

    func reconcile() throws {
        var manifest = loadManifest()
        var changed = false
        for (fontID, entry) in manifest {
            if let installed = entry.installedURL {
                if !fileManager.fileExists(atPath: installed.path) {
                    manifest.removeValue(forKey: fontID)
                    changed = true
                }
            } else if !fileManager.fileExists(atPath: entry.originalURL.path) {
                manifest.removeValue(forKey: fontID)
                changed = true
            }
        }
        if changed { saveManifest(manifest) }
    }

    func isManaged(fontID: String) -> Bool {
        loadManifest()[fontID] != nil
    }

    func managedCount() -> Int {
        loadManifest().count
    }

    func managedFontIDs() -> Set<String> {
        Set(loadManifest().keys)
    }

    func managedFontsDirectoryURL() -> URL {
        userInstallDirectoryURL
    }

    private func resolveURL(for fontID: String) throws -> URL {
        let urls = availableFontURLsProvider()
        guard let url = urls.first(where: { $0.deletingPathExtension().lastPathComponent == fontID }) else {
            throw FontActivationError.fontNotFound
        }
        return url
    }

    private func register(urls: [URL], scope: CTFontManagerScope) throws {
        try registerAction(urls, scope)
    }

    private func unregister(urls: [URL], scope: CTFontManagerScope) throws {
        try unregisterAction(urls, scope)
    }

    private static func defaultRegister(urls: [URL], scope: CTFontManagerScope) throws {
        for url in urls {
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, scope, &error)
            if !ok, let cfError = error?.takeRetainedValue() {
                throw cfError as Error
            }
        }
    }

    private static func defaultUnregister(urls: [URL], scope: CTFontManagerScope) throws {
        for url in urls {
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerUnregisterFontsForURL(url as CFURL, scope, &error)
            if !ok, let cfError = error?.takeRetainedValue() {
                throw cfError as Error
            }
        }
    }

    private func loadManifest() -> [String: ActivatedFontEntry] {
        guard let data = try? Data(contentsOf: appSupportManifestURL),
              let decoded = try? JSONDecoder().decode([String: ActivatedFontEntry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveManifest(_ manifest: [String: ActivatedFontEntry]) {
        let directory = appSupportManifestURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: appSupportManifestURL, options: .atomic)
    }
}
