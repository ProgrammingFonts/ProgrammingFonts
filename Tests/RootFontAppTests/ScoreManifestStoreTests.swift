import Foundation
import XCTest
@testable import RootFontApp

final class ScoreManifestStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifestURL = temp.appendingPathComponent("scores.json")
        let store = ScoreManifestStore(manifestURL: manifestURL)

        let entries: [String: CachedScoreEntry] = [
            "Menlo|1": CachedScoreEntry(
                programming: ProgrammingProfile.empty.withMonospaced(true),
                metrics: FontMetricsSample(asciiAdvanceVariance: 0.1, uniformWidth: true, confusableDistances: [:]),
                score: ProgrammingScore(total: 70, grade: .a, breakdown: [])
            )
        ]

        store.save(entries)
        let loaded = store.load()
        XCTAssertEqual(loaded, entries)
    }

    func testCacheKeyChangesWhenMtimeChanges() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let fontURL = temp.appendingPathComponent("Demo.ttf")
        try Data("a".utf8).write(to: fontURL)
        let store = ScoreManifestStore(manifestURL: temp.appendingPathComponent("scores.json"))
        let key1 = store.cacheKey(for: "Demo", fileURL: fontURL)

        Thread.sleep(forTimeInterval: 1.1)
        try Data("ab".utf8).write(to: fontURL)
        let key2 = store.cacheKey(for: "Demo", fileURL: fontURL)

        XCTAssertNotEqual(key1, key2)
    }
}

private extension ProgrammingProfile {
    func withMonospaced(_ value: Bool) -> ProgrammingProfile {
        var copy = self
        copy.isMonospaced = value
        return copy
    }
}
