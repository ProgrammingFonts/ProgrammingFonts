import AppKit
import XCTest
@testable import RootFontApp

final class CompareReportExporterTests: XCTestCase {
    func testTextReportIncludesScoresAndSnippet() {
        let baselineScore = ProgrammingScore(
            total: 70,
            grade: .a,
            breakdown: []
        )
        let candidateScore = ProgrammingScore(
            total: 82,
            grade: .s,
            breakdown: []
        )
        let input = CompareReportInput(
            baselineFamilyName: "JetBrains Mono",
            candidateFamilyName: "Fira Code",
            baselinePostScriptName: "JetBrainsMono-Regular",
            candidatePostScriptName: "FiraCode-Regular",
            baselineScore: baselineScore,
            candidateScore: candidateScore,
            baselineProfile: nil,
            candidateProfile: nil,
            codeSnippet: "fn main() {}",
            previewSize: 14,
            factorTitle: { _ in "Factor" },
            bucketTitle: { _ in "Bucket" }
        )

        let report = CompareReportExporter.textReport(input: input)

        XCTAssertTrue(report.contains("JetBrains Mono"))
        XCTAssertTrue(report.contains("Fira Code"))
        XCTAssertTrue(report.contains("70 -> 82"))
        XCTAssertTrue(report.contains("fn main() {}"))
    }

    func testPNGExportProducesData() {
        let baselineScore = ProgrammingScore(total: 60, grade: .b, breakdown: [])
        let candidateScore = ProgrammingScore(total: 75, grade: .a, breakdown: [])
        let input = CompareReportInput(
            baselineFamilyName: "Alpha",
            candidateFamilyName: "Beta",
            baselinePostScriptName: "Menlo-Regular",
            candidatePostScriptName: "Monaco",
            baselineScore: baselineScore,
            candidateScore: candidateScore,
            baselineProfile: nil,
            candidateProfile: nil,
            codeSnippet: "let x = 1",
            previewSize: 14,
            factorTitle: { _ in "Factor" },
            bucketTitle: { _ in "Bucket" }
        )

        let data = CompareReportExporter.pngData(input: input)
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 100)
    }
}

final class SpecimenExporterPDFTests: XCTestCase {
    func testPDFExportProducesData() {
        let font = NSFont.monospacedSystemFont(ofSize: 24, weight: .regular)
        let data = SpecimenExporter.pdfData(
            familyName: "Menlo",
            displayName: "Menlo Regular",
            postScriptName: "Menlo-Regular",
            previewText: "Hello rootfont",
            size: 24,
            font: font
        )
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 100)
    }
}

final class FontCatalogWatcherTests: XCTestCase {
    func testDefaultWatchURLsIncludeUserFontsDirectory() {
        let urls = FontCatalogWatcher.defaultWatchURLs()
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.lastPathComponent, "Fonts")
    }

    func testWatcherCanStartAndStopRepeatedly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let watcher = FontCatalogWatcher(urls: [directory], onChange: {})

        watcher.start()
        watcher.stop()
        watcher.start()
        watcher.stop()
    }
}

final class FileExportServiceTests: XCTestCase {
    func testWritePersistsDataAtomically() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("report.txt")

        try FileExportService.write(Data("report".utf8), to: destination)

        XCTAssertEqual(try Data(contentsOf: destination), Data("report".utf8))
    }

    func testWriteThrowsForDirectoryDestination() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try FileExportService.write(Data("report".utf8), to: directory))
    }
}
