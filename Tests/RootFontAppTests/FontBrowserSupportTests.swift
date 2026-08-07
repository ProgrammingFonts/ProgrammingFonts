import Foundation
import XCTest
@testable import RootFontApp

final class FontBrowserPreferencesCodecTests: XCTestCase {
    func testRoundTrip() {
        let original = ["Mono": ["coding", "favorite"]]
        let data = FontBrowserPreferencesCodec.encode(original)

        let decoded = FontBrowserPreferencesCodec.decode(
            [String: [String]].self,
            from: data,
            default: [:]
        )

        XCTAssertEqual(decoded, original)
    }

    func testInvalidDataReturnsDefault() {
        let decoded = FontBrowserPreferencesCodec.decode(
            [String].self,
            from: Data("not-json".utf8),
            default: ["fallback"]
        )

        XCTAssertEqual(decoded, ["fallback"])
    }
}

final class FontFilterResultCacheTests: XCTestCase {
    func testEvictsOldestSignatureAtLimit() {
        let cache = FontFilterResultCache(limit: 2)
        let first = signature(query: "first")
        let second = signature(query: "second")
        let third = signature(query: "third")

        cache.store(fontIDs: ["a"], for: first)
        cache.store(fontIDs: ["b"], for: second)
        cache.store(fontIDs: ["c"], for: third)

        XCTAssertNil(cache.value(for: first))
        XCTAssertEqual(cache.value(for: second), ["b"])
        XCTAssertEqual(cache.value(for: third), ["c"])
    }

    func testClearRemovesCachedResults() {
        let cache = FontFilterResultCache(limit: 2)
        let key = signature(query: "query")
        cache.store(fontIDs: ["a"], for: key)

        cache.clear()

        XCTAssertNil(cache.value(for: key))
    }

    private func signature(query: String) -> FontFilterSignature {
        FontFilterSignature(
            searchQuery: query,
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: false,
            catalogEpoch: 0,
            favoritesSignature: 0,
            recentsSignature: 0,
            workspaceModule: .library,
            managedSignature: 0,
            scoreWeightsSignature: 0,
            manualCollectionSignature: 0,
            tagFilterSignature: 0,
            fontHealthSignature: 0
        )
    }
}

final class FontCollectionControllerTests: XCTestCase {
    func testManualCollectionTrimsNameAndIncludesSelection() {
        let collection = FontCollectionController.manualCollection(
            named: "  Coding  ",
            selectedFontID: "Mono"
        )

        XCTAssertEqual(collection?.name, "Coding")
        XCTAssertEqual(collection?.fontIDs, ["Mono"])
    }

    func testToggleTagRemovesEmptyAssignmentAndBuildsIndex() {
        var assignments = ["Mono": ["coding"]]
        FontCollectionController.toggleTag(
            "coding",
            fontID: "Mono",
            assignments: &assignments
        )
        XCTAssertNil(assignments["Mono"])

        XCTAssertEqual(
            FontCollectionController.addTag(
                named: " terminal ",
                fontID: "Mono",
                assignments: &assignments
            ),
            "terminal"
        )
        let index = FontCollectionController.tagIndex(assignments: assignments)
        XCTAssertEqual(index.fontIDsByTag["terminal"], ["Mono"])
        XCTAssertEqual(index.sortedNames, ["terminal"])
    }

    func testRejectsBlankNamesAndDuplicateTags() {
        XCTAssertNil(
            FontCollectionController.manualCollection(
                named: " \n ",
                selectedFontID: nil
            )
        )
        XCTAssertNil(
            FontCollectionController.smartCollection(
                named: "\t",
                searchQuery: "",
                glyphCoverageQuery: "",
                selectedSource: nil,
                selectedStyle: nil,
                sidebarFilter: .all
            )
        )

        var assignments = ["Mono": ["terminal"]]
        XCTAssertNil(
            FontCollectionController.addTag(
                named: " terminal ",
                fontID: "Mono",
                assignments: &assignments
            )
        )
        XCTAssertEqual(assignments, ["Mono": ["terminal"]])
    }

    func testToggleFontReturnsFalseForUnknownCollection() {
        var collections = [ManualCollection(name: "Coding", fontIDs: [])]

        XCTAssertFalse(
            FontCollectionController.toggleFont(
                fontID: "Mono",
                collectionID: "missing",
                in: &collections
            )
        )
        XCTAssertTrue(collections[0].fontIDs.isEmpty)
    }
}

@MainActor
final class ProgrammingScoreCoordinatorTests: XCTestCase {
    func testScheduleAppliesCalculatedFontsAndCompletes() async {
        let coordinator = ProgrammingScoreCoordinator()
        var applied: [FontItem] = []
        var completed = false
        let font = FontItem.sample(
            id: "mono",
            familyName: "Mono",
            source: .user,
            styleTags: [.monospace]
        )

        coordinator.schedule(
            calculation: { [font] },
            apply: { applied = $0 },
            completion: { completed = true }
        )
        await coordinator.waitUntilIdle()

        XCTAssertEqual(applied.map(\.id), ["mono"])
        XCTAssertTrue(completed)
    }

    func testNewestCalculationWins() async throws {
        let coordinator = ProgrammingScoreCoordinator()
        var appliedIDs: [String] = []

        coordinator.schedule(
            calculation: {
                Thread.sleep(forTimeInterval: 0.08)
                return [.sample(id: "old", familyName: "Old", source: .user, styleTags: [])]
            },
            apply: { appliedIDs.append(contentsOf: $0.map(\.id)) },
            completion: {}
        )
        coordinator.schedule(
            calculation: { [.sample(id: "new", familyName: "New", source: .user, styleTags: [])] },
            apply: { appliedIDs.append(contentsOf: $0.map(\.id)) },
            completion: {}
        )

        await coordinator.waitUntilIdle()
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(appliedIDs, ["new"])
    }

    func testCancelPreventsResultApplication() async throws {
        let coordinator = ProgrammingScoreCoordinator()
        var didApply = false
        var didComplete = false

        coordinator.schedule(
            calculation: {
                Thread.sleep(forTimeInterval: 0.05)
                return [.sample(id: "mono", familyName: "Mono", source: .user, styleTags: [])]
            },
            apply: { _ in didApply = true },
            completion: { didComplete = true }
        )
        coordinator.cancel()

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(didApply)
        XCTAssertFalse(didComplete)
    }

    func testDebounceRunsOnlyLatestAction() async {
        let coordinator = ProgrammingScoreCoordinator()
        var values: [Int] = []

        coordinator.scheduleDebounced(delayNanoseconds: 20_000_000) {
            values.append(1)
        }
        coordinator.scheduleDebounced(delayNanoseconds: 20_000_000) {
            values.append(2)
        }
        await coordinator.waitUntilIdle()

        XCTAssertEqual(values, [2])
    }

    func testFlushDebounceRunsImmediatelyWithoutRepeating() async throws {
        let coordinator = ProgrammingScoreCoordinator()
        var values: [Int] = []

        coordinator.scheduleDebounced(delayNanoseconds: 80_000_000) {
            values.append(1)
        }
        coordinator.flushDebounce {
            values.append(2)
        }
        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(values, [2])
    }
}
