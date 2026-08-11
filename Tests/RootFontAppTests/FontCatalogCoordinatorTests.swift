import Foundation
import XCTest
@testable import RootFontApp

@MainActor
final class FontCatalogCoordinatorTests: XCTestCase {
    func testLoadForwardsPartialProgressAndCompletion() async {
        let font = FontItem.sample(id: "mono", familyName: "Mono", source: .user, styleTags: [])
        let coordinator = FontCatalogCoordinator()
        var partialIDs: [String] = []
        var progress: Double?
        var outcome: FontCatalogLoadOutcome?

        coordinator.load(
            service: MockCatalogService(fonts: [font]),
            onPartial: { partialIDs = $0.map(\.id) },
            onProgress: { progress = $0 },
            completion: { outcome = $0 }
        )
        await waitUntilIdle(coordinator)

        XCTAssertEqual(partialIDs, ["mono"])
        XCTAssertEqual(progress, 1.0)
        XCTAssertEqual(outcome?.fonts?.map(\.id), ["mono"])
        XCTAssertFalse(outcome?.failed ?? true)
    }

    func testLoadReportsFailure() async {
        let coordinator = FontCatalogCoordinator()
        var outcome: FontCatalogLoadOutcome?
        coordinator.load(
            service: MockCatalogService(fonts: [], error: TestError.failed),
            onPartial: { _ in },
            onProgress: { _ in },
            completion: { outcome = $0 }
        )
        await waitUntilIdle(coordinator)

        XCTAssertTrue(outcome?.failed ?? false)
        XCTAssertNil(outcome?.fonts)
    }

    func testCancelPreventsLateCompletion() async throws {
        let coordinator = FontCatalogCoordinator()
        var completed = false
        coordinator.load(
            service: SlowCatalogService(),
            onPartial: { _ in },
            onProgress: { _ in },
            completion: { _ in completed = true }
        )
        coordinator.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(completed)
        XCTAssertFalse(coordinator.isLoading)
    }

    func testCatalogChangeBurstCoalescesDuringLoad() async {
        let coordinator = FontCatalogCoordinator()
        var reloadCount = 0
        coordinator.setReloadHandler { reloadCount += 1 }
        coordinator.load(
            service: SlowCatalogService(),
            onPartial: { _ in },
            onProgress: { _ in },
            completion: { _ in }
        )
        coordinator.handleCatalogChange()
        coordinator.handleCatalogChange()
        coordinator.handleCatalogChange()
        await waitUntilIdle(coordinator)

        XCTAssertEqual(reloadCount, 1)
    }

    private func waitUntilIdle(_ coordinator: FontCatalogCoordinator) async {
        while coordinator.isLoading {
            await Task.yield()
        }
        await Task.yield()
    }
}

private enum TestError: Error, Sendable {
    case failed
}

private struct SlowCatalogService: FontCatalogServiceProtocol {
    func loadFonts() -> AsyncStream<FontCatalogEvent> {
        AsyncStream { continuation in
            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(nanoseconds: 50_000_000)
                continuation.yield(.partial([]))
                continuation.yield(.progress(1.0))
                continuation.yield(.completed([]))
                continuation.finish()
            }
        }
    }
}
