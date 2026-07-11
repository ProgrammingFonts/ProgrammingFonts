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

    func testRepeatedLoadsUseUpdatedCacheAfterSave() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifestURL = temp.appendingPathComponent("scores.json")
        let store = ScoreManifestStore(manifestURL: manifestURL)

        let initial: [String: CachedScoreEntry] = [
            "Mono|1": CachedScoreEntry(
                programming: ProgrammingProfile.empty.withMonospaced(true),
                metrics: nil,
                score: nil
            )
        ]
        store.save(initial)
        XCTAssertEqual(store.load().keys.sorted(), ["Mono|1"])

        let updated: [String: CachedScoreEntry] = [
            "Mono|1": initial["Mono|1"]!,
            "Mono|2": CachedScoreEntry(
                programming: ProgrammingProfile.empty.withMonospaced(true),
                metrics: nil,
                score: nil
            )
        ]
        store.save(updated)
        XCTAssertEqual(store.load().keys.sorted(), ["Mono|1", "Mono|2"])
    }

    func testSaveSkipsWriteWhenEntriesUnchanged() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let manifestURL = temp.appendingPathComponent("scores.json")
        let store = ScoreManifestStore(manifestURL: manifestURL)

        let entries: [String: CachedScoreEntry] = [
            "Mono|1": CachedScoreEntry(
                programming: ProgrammingProfile.empty.withMonospaced(true),
                metrics: nil,
                score: nil
            )
        ]
        store.save(entries)

        let attrsAfterFirstSave = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        let mtimeAfterFirstSave = (attrsAfterFirstSave[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

        Thread.sleep(forTimeInterval: 1.1)
        store.save(entries)

        let attrsAfterSecondSave = try FileManager.default.attributesOfItem(atPath: manifestURL.path)
        let mtimeAfterSecondSave = (attrsAfterSecondSave[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        XCTAssertEqual(mtimeAfterFirstSave, mtimeAfterSecondSave, accuracy: 0.001)
    }

    func testCachedMetadataRoundTripsThroughManifest() throws {
        let metadata = CachedCatalogMetadata(
            familyName: "Mono",
            displayName: "Mono Regular",
            source: .user,
            styleTags: [.regular, .monospace],
            localizedFamilyNames: ["ja": "モノ"],
            localizedDisplayNames: ["ja": "モノ レギュラー"]
        )
        let entry = CachedScoreEntry(
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: nil,
            score: ProgrammingScore(total: 65, grade: .b, breakdown: []),
            metadata: metadata
        )

        let item = entry.fontItem(postScriptName: "Mono-Regular")
        XCTAssertEqual(item?.familyName, "Mono")
        XCTAssertEqual(item?.localizedFamilyNames["ja"], "モノ")
        XCTAssertEqual(item?.programmingScore?.total, 65)

        let withTier = CachedScoreEntry(
            programming: entry.programming,
            metrics: entry.metrics,
            score: entry.score,
            metadata: CachedCatalogMetadata(
                familyName: metadata.familyName,
                displayName: metadata.displayName,
                source: metadata.source,
                styleTags: metadata.styleTags,
                localizedFamilyNames: metadata.localizedFamilyNames,
                localizedDisplayNames: metadata.localizedDisplayNames,
                weightTier: .bold
            )
        )
        XCTAssertEqual(withTier.fontItem(postScriptName: "Mono-Regular")?.weightTier, .bold)

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CachedScoreEntry.self, from: encoded)
        XCTAssertEqual(decoded, entry)
        XCTAssertNil(decoded.fontItem(postScriptName: "Legacy-Regular"))
    }

    func testLegacyEntryWithoutMetadataDecodes() throws {
        let legacyJSON = """
        {"programming":{"isMonospaced":true,"hasProgrammingLigatures":false,"availableStylisticSets":[],"hasZeroVariant":false,"hasPowerlineGlyphs":false,"hasNerdFontGlyphs":false,"hasBoxDrawing":false,"coverageBuckets":[],"isVariableFont":false},"metrics":null,"score":null}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CachedScoreEntry.self, from: legacyJSON)
        XCTAssertNil(decoded.metadata)
        XCTAssertNil(decoded.fontItem(postScriptName: "Mono-Regular"))
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
