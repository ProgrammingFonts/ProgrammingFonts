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

    private func makeSandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
