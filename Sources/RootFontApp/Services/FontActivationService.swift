import CoreText
import Foundation
import os

enum FontActivationScope: String, Codable, Sendable {
    case process
    case user
}

enum FontActivationError: Error, Sendable {
    case fontNotFound
    case invalidFontFile(URL)
    case installConflict(destination: URL)
    case rollbackFailed(primary: String, cleanup: [String])
}

struct ActivatedFontEntry: Codable, Hashable, Sendable {
    var fontID: String
    var originalURL: URL
    var installedURL: URL?
    var scope: FontActivationScope
}

/// Persisted manifest wrapper with a schema version. Older manifests
/// without a version field decode as v1 and migrate forward on next save.
struct ActivatedFontManifest: Codable, Sendable {
    static let currentSchemaVersion = 2

    var version: Int
    var entries: [String: ActivatedFontEntry]

    init(version: Int = ActivatedFontManifest.currentSchemaVersion, entries: [String: ActivatedFontEntry] = [:]) {
        self.version = version
        self.entries = entries
    }
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
    private final class ManifestMemoryCache: @unchecked Sendable {
        private var lock = os_unfair_lock_s()
        private var manifest: [String: ActivatedFontEntry]?

        func read() -> [String: ActivatedFontEntry]? {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return manifest
        }

        func write(_ value: [String: ActivatedFontEntry]) {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            manifest = value
        }
    }

    private let fileManager: FileManager
    private let appSupportManifestURL: URL
    private let userInstallDirectoryURL: URL
    private let availableFontURLsProvider: @Sendable () -> [URL]
    private let usesInjectedFontURLs: Bool
    private let fontURLIndex: FontURLIndex
    private let registerAction: @Sendable ([URL], CTFontManagerScope) throws -> Void
    private let unregisterAction: @Sendable ([URL], CTFontManagerScope) throws -> Void
    private let manifestCache = ManifestMemoryCache()

    init(
        fileManager: FileManager = .default,
        manifestURL: URL? = nil,
        userInstallDirectoryURL: URL? = nil,
        availableFontURLsProvider: (@Sendable () -> [URL])? = nil,
        fontURLIndex: FontURLIndex = .shared,
        registerAction: (@Sendable ([URL], CTFontManagerScope) throws -> Void)? = nil,
        unregisterAction: (@Sendable ([URL], CTFontManagerScope) throws -> Void)? = nil
    ) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.appSupportManifestURL = manifestURL ?? appSupport
            .appendingPathComponent("rootfont", isDirectory: true)
            .appendingPathComponent("activated-fonts.json")
        self.userInstallDirectoryURL = userInstallDirectoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Fonts/rootfont", isDirectory: true)
        self.usesInjectedFontURLs = availableFontURLsProvider != nil
        self.fontURLIndex = fontURLIndex
        self.availableFontURLsProvider = availableFontURLsProvider ?? {
            fontURLIndex.urls
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
        do {
            var manifest = loadManifest()
            manifest[fontID] = ActivatedFontEntry(
                fontID: fontID,
                originalURL: url,
                installedURL: nil,
                scope: .process
            )
            try saveManifest(manifest)
        } catch {
            do {
                try unregister(urls: [url], scope: .process)
            } catch let cleanupError {
                throw rollbackFailure(primary: error, cleanup: [cleanupError])
            }
            throw error
        }
    }

    func installForUser(fontID: String) throws {
        let original = try resolveURL(for: fontID)
        try validateFontFileURL(original)
        try fileManager.createDirectory(at: userInstallDirectoryURL, withIntermediateDirectories: true)
        let destination = userInstallDirectoryURL.appendingPathComponent(original.lastPathComponent)
        try validateManagedDestination(destination)
        if fileManager.fileExists(atPath: destination.path) {
            throw FontActivationError.installConflict(destination: destination)
        }
        try fileManager.copyItem(at: original, to: destination)
        var registered = false
        do {
            try register(urls: [destination], scope: .user)
            registered = true
            var manifest = loadManifest()
            manifest[fontID] = ActivatedFontEntry(
                fontID: fontID,
                originalURL: original,
                installedURL: destination,
                scope: .user
            )
            try saveManifest(manifest)
        } catch {
            var cleanupErrors: [Error] = []
            if registered {
                do {
                    try unregister(urls: [destination], scope: .user)
                } catch {
                    cleanupErrors.append(error)
                }
            }
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
            } catch {
                cleanupErrors.append(error)
            }
            if !cleanupErrors.isEmpty {
                throw rollbackFailure(primary: error, cleanup: cleanupErrors)
            }
            throw error
        }
    }

    func uninstall(fontID: String) throws {
        let originalManifest = loadManifest()
        guard let entry = originalManifest[fontID] else { return }
        var updatedManifest = originalManifest
        updatedManifest.removeValue(forKey: fontID)

        if let installed = entry.installedURL {
            try unregister(urls: [installed], scope: .user)
            let backup = installed.deletingLastPathComponent()
                .appendingPathComponent(".\(installed.lastPathComponent).rootfont-uninstall-\(UUID().uuidString)")
            do {
                if fileManager.fileExists(atPath: installed.path) {
                    try fileManager.moveItem(at: installed, to: backup)
                }
                try saveManifest(updatedManifest)
                if fileManager.fileExists(atPath: backup.path) {
                    try fileManager.removeItem(at: backup)
                }
            } catch {
                var cleanupErrors: [Error] = []
                if fileManager.fileExists(atPath: backup.path),
                   !fileManager.fileExists(atPath: installed.path) {
                    do {
                        try fileManager.moveItem(at: backup, to: installed)
                    } catch {
                        cleanupErrors.append(error)
                    }
                }
                do {
                    try register(urls: [installed], scope: .user)
                } catch {
                    cleanupErrors.append(error)
                }
                if manifestCache.read() != originalManifest {
                    do {
                        try saveManifest(originalManifest)
                    } catch {
                        cleanupErrors.append(error)
                    }
                }
                if !cleanupErrors.isEmpty {
                    throw rollbackFailure(primary: error, cleanup: cleanupErrors)
                }
                throw error
            }
        } else {
            try unregister(urls: [entry.originalURL], scope: .process)
            do {
                try saveManifest(updatedManifest)
            } catch {
                do {
                    try register(urls: [entry.originalURL], scope: .process)
                } catch let cleanupError {
                    throw rollbackFailure(primary: error, cleanup: [cleanupError])
                }
                throw error
            }
        }
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
        if changed { try saveManifest(manifest) }
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
        if usesInjectedFontURLs {
            let urls = availableFontURLsProvider()
            guard let url = urls.first(where: { $0.deletingPathExtension().lastPathComponent == fontID }) else {
                throw FontActivationError.fontNotFound
            }
            return url
        }
        guard let url = fontURLIndex.url(forPostScriptName: fontID) else {
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

    private func rollbackFailure(primary: Error, cleanup: [Error]) -> FontActivationError {
        FontActivationError.rollbackFailed(
            primary: String(describing: primary),
            cleanup: cleanup.map { String(describing: $0) }
        )
    }

    private func validateFontFileURL(_ url: URL) throws {
        let allowedExtensions = ["ttf", "otf", "ttc", "otc", "dfont", "woff", "woff2"]
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            throw FontActivationError.invalidFontFile(url)
        }
        // Reject symlinks and other non-regular files to prevent a
        // maliciously crafted link from copying a system file into the
        // managed fonts directory.
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        if let attrs,
           let type = attrs[.type] as? FileAttributeType,
           type != .typeRegular {
            AppLog.activation.error("rejecting non-regular font file: \(url.path, privacy: .public)")
            throw FontActivationError.invalidFontFile(url)
        }
    }

    private func validateManagedDestination(_ destination: URL) throws {
        let managedRoot = userInstallDirectoryURL.standardizedFileURL.path
        let candidate = destination.standardizedFileURL.path
        guard candidate == managedRoot || candidate.hasPrefix(managedRoot + "/") else {
            throw FontActivationError.invalidFontFile(destination)
        }
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
        if let cachedManifest = manifestCache.read() {
            return cachedManifest
        }
        let manifest = readManifestFromDisk()
        manifestCache.write(manifest)
        return manifest
    }

    private func readManifestFromDisk() -> [String: ActivatedFontEntry] {
        guard let data = try? Data(contentsOf: appSupportManifestURL) else {
            return [:]
        }
        // Try the new versioned wrapper first, then fall back to the
        // legacy bare `[String: ActivatedFontEntry]` layout (v1).
        if let wrapped = try? JSONDecoder().decode(ActivatedFontManifest.self, from: data) {
            if wrapped.version < ActivatedFontManifest.currentSchemaVersion {
                AppLog.activation.info("activation manifest migrating v\(wrapped.version, privacy: .public) -> v\(ActivatedFontManifest.currentSchemaVersion, privacy: .public)")
            }
            return wrapped.entries
        }
        if let legacy = try? JSONDecoder().decode([String: ActivatedFontEntry].self, from: data) {
            AppLog.activation.info("activation manifest migrated legacy v1 layout")
            return legacy
        }
        AppLog.activation.error("activation manifest decode failed; ignoring existing file")
        return [:]
    }

    private func saveManifest(_ manifest: [String: ActivatedFontEntry]) throws {
        if manifestCache.read() == manifest {
            return
        }

        let directory = appSupportManifestURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let wrapped = ActivatedFontManifest(
                version: ActivatedFontManifest.currentSchemaVersion,
                entries: manifest
            )
            let data = try JSONEncoder().encode(wrapped)
            try data.write(to: appSupportManifestURL, options: .atomic)
            manifestCache.write(manifest)
        } catch {
            AppLog.activation.error("activation manifest save failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}
