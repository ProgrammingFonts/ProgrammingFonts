import Foundation
import XCTest
@testable import RootFontApp

@MainActor
final class ProgrammingScoreCoordinatorTests: XCTestCase {
    func testScheduleAppliesCalculatedFontsAndCompletes() async {
        let coordinator = ProgrammingScoreCoordinator()
        var applied: [FontItem] = []
        var completed = false
        let font = FontItem.sample(id: "mono", familyName: "Mono", source: .user, styleTags: [.monospace])
        coordinator.schedule(
            calculation: { [font] }, apply: { applied = $0 }, completion: { completed = true }
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
            }, apply: { appliedIDs.append(contentsOf: $0.map(\.id)) }, completion: {}
        )
        coordinator.schedule(
            calculation: { [.sample(id: "new", familyName: "New", source: .user, styleTags: [])] },
            apply: { appliedIDs.append(contentsOf: $0.map(\.id)) }, completion: {}
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
            }, apply: { _ in didApply = true }, completion: { didComplete = true }
        )
        coordinator.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(didApply)
        XCTAssertFalse(didComplete)
    }

    func testDebounceRunsOnlyLatestAction() async {
        let coordinator = ProgrammingScoreCoordinator()
        var values: [Int] = []
        coordinator.scheduleDebounced(delayNanoseconds: 20_000_000) { values.append(1) }
        coordinator.scheduleDebounced(delayNanoseconds: 20_000_000) { values.append(2) }
        await coordinator.waitUntilIdle()
        XCTAssertEqual(values, [2])
    }

    func testFlushDebounceRunsImmediatelyWithoutRepeating() async throws {
        let coordinator = ProgrammingScoreCoordinator()
        var values: [Int] = []
        coordinator.scheduleDebounced(delayNanoseconds: 80_000_000) { values.append(1) }
        coordinator.flushDebounce { values.append(2) }
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(values, [2])
    }
}
