import Foundation
import XCTest
@testable import RootFontApp

final class FontActivationServiceTests: XCTestCase {
    func testInstallForUserCopiesFontAndWritesManifest() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: sandbox.appendingPathComponent("UserFonts", isDirectory: true),
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        try service.installForUser(fontID: "Fira")
        XCTAssertTrue(service.isManaged(fontID: "Fira"))
        XCTAssertEqual(service.managedCount(), 1)
    }

    func testInstallConflictThrowsError() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        let userFonts = sandbox.appendingPathComponent("UserFonts", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userFonts, withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)
        try Data("existing".utf8).write(to: userFonts.appendingPathComponent("Fira.ttf"))

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: userFonts,
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        XCTAssertThrowsError(try service.installForUser(fontID: "Fira")) { error in
            guard case FontActivationError.installConflict = error else {
                return XCTFail("Expected installConflict, got \(error)")
            }
        }
    }

    func testInstallRegistrationFailureRemovesCopiedFont() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        let userFonts = sandbox.appendingPathComponent("UserFonts", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: userFonts,
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in throw TestFailure.expected },
            unregisterAction: { _, _ in }
        )

        XCTAssertThrowsError(try service.installForUser(fontID: "Fira"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: userFonts.appendingPathComponent("Fira.ttf").path))
        XCTAssertFalse(service.isManaged(fontID: "Fira"))
    }

    func testInstallRejectsUnsupportedFileExtension() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFile = sandbox.appendingPathComponent("Source/Readme.txt")
        try FileManager.default.createDirectory(at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-a-font".utf8).write(to: sourceFile)

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: sandbox.appendingPathComponent("UserFonts", isDirectory: true),
            availableFontURLsProvider: { [sourceFile] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        XCTAssertThrowsError(try service.installForUser(fontID: "Readme")) { error in
            guard case FontActivationError.invalidFontFile = error else {
                return XCTFail("Expected invalidFontFile, got \(error)")
            }
        }
    }

    func testInstallManifestFailureRollsBackRegistrationAndCopiedFont() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        let userFonts = sandbox.appendingPathComponent("UserFonts", isDirectory: true)
        let invalidManifestURL = sandbox.appendingPathComponent("manifest.json", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: invalidManifestURL, withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)
        let unregisterCount = LockedCounter()

        let service = FontActivationService(
            manifestURL: invalidManifestURL,
            userInstallDirectoryURL: userFonts,
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in unregisterCount.increment() }
        )

        XCTAssertThrowsError(try service.installForUser(fontID: "Fira"))
        XCTAssertEqual(unregisterCount.value, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: userFonts.appendingPathComponent("Fira.ttf").path))
        XCTAssertFalse(service.isManaged(fontID: "Fira"))
    }

    func testReconcileRemovesMissingEntries() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let manifestURL = sandbox.appendingPathComponent("manifest.json")
        let missing = sandbox.appendingPathComponent("missing.ttf")
        let manifest = [
            "Ghost": ActivatedFontEntry(
                fontID: "Ghost",
                originalURL: missing,
                installedURL: nil,
                scope: .process
            )
        ]
        try JSONEncoder().encode(manifest).write(to: manifestURL)

        let service = FontActivationService(
            manifestURL: manifestURL,
            userInstallDirectoryURL: sandbox.appendingPathComponent("UserFonts", isDirectory: true),
            availableFontURLsProvider: { [] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        try service.reconcile()
        XCTAssertEqual(service.managedCount(), 0)
    }

    func testUninstallUpdatesManagedStateWithoutStaleCache() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: sandbox.appendingPathComponent("UserFonts", isDirectory: true),
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        try service.installForUser(fontID: "Fira")
        XCTAssertTrue(service.isManaged(fontID: "Fira"))
        XCTAssertEqual(service.managedFontIDs(), ["Fira"])

        try service.uninstall(fontID: "Fira")
        XCTAssertFalse(service.isManaged(fontID: "Fira"))
        XCTAssertEqual(service.managedCount(), 0)
        XCTAssertTrue(service.managedFontIDs().isEmpty)
    }

    func testUninstallManifestFailureRestoresInstalledFontAndRegistration() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        let userFonts = sandbox.appendingPathComponent("UserFonts", isDirectory: true)
        let manifestURL = sandbox.appendingPathComponent("manifest.json")
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)
        let registerCount = LockedCounter()

        let service = FontActivationService(
            manifestURL: manifestURL,
            userInstallDirectoryURL: userFonts,
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in registerCount.increment() },
            unregisterAction: { _, _ in }
        )

        try service.installForUser(fontID: "Fira")
        try FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)

        XCTAssertThrowsError(try service.uninstall(fontID: "Fira"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: userFonts.appendingPathComponent("Fira.ttf").path))
        XCTAssertTrue(service.isManaged(fontID: "Fira"))
        XCTAssertEqual(registerCount.value, 2)
    }

    func testSaveSkipsWriteWhenManifestUnchanged() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox.appendingPathComponent("Source/Fira.ttf")
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)
        let manifestURL = sandbox.appendingPathComponent("manifest.json")

        let service = FontActivationService(
            manifestURL: manifestURL,
            userInstallDirectoryURL: sandbox.appendingPathComponent("UserFonts", isDirectory: true),
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        try service.activateForProcess(fontID: "Fira")
        let attrsAfterFirstSave = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        let mtimeAfterFirstSave = (attrsAfterFirstSave[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

        Thread.sleep(forTimeInterval: 1.1)
        try service.activateForProcess(fontID: "Fira")

        let attrsAfterSecondSave = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        let mtimeAfterSecondSave = (attrsAfterSecondSave[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(mtimeAfterFirstSave, mtimeAfterSecondSave, accuracy: 0.001)
    }

    func testManagedInstallStaysInsideManagedDirectory() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let sourceFont = sandbox
            .appendingPathComponent("Source")
            .appendingPathComponent("nested/../Fira.ttf")
            .standardizedFileURL
        try FileManager.default.createDirectory(at: sourceFont.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("font".utf8).write(to: sourceFont)
        let userFonts = sandbox.appendingPathComponent("UserFonts", isDirectory: true)

        let service = FontActivationService(
            manifestURL: sandbox.appendingPathComponent("manifest.json"),
            userInstallDirectoryURL: userFonts,
            availableFontURLsProvider: { [sourceFont] },
            registerAction: { _, _ in },
            unregisterAction: { _, _ in }
        )

        try service.installForUser(fontID: "Fira")

        let installed = userFonts.appendingPathComponent("Fira.ttf").standardizedFileURL.path
        XCTAssertTrue(installed.hasPrefix(userFonts.standardizedFileURL.path + "/"))
    }

    private func makeSandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum TestFailure: Error {
    case expected
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
