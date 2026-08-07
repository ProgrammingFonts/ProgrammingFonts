import Foundation
import XCTest
@testable import RootFontApp

@MainActor
final class FontFilterCoordinatorTests: XCTestCase {
    func testCachePreservesResultUntilInvalidated() {
        let first = font("first")
        let second = font("second")
        let coordinator = FontFilterCoordinator(
            compute: { request in
                FontFilterEngine.ComputeOutput(
                    fonts: request.fonts,
                    coverageCacheUpdates: [:]
                )
            }
        )
        var results: [[String]] = []
        let firstRequest = request(fonts: [first])
        coordinator.apply(firstRequest) {
            results.append($0.fonts.map(\.id))
        }
        coordinator.apply(firstRequest) {
            results.append($0.fonts.map(\.id))
        }
        XCTAssertEqual(results, [["first"], ["first"]])

        coordinator.invalidate()
        coordinator.apply(request(fonts: [second])) {
            results.append($0.fonts.map(\.id))
        }
        XCTAssertEqual(results.last, ["second"])
    }

    func testNewerAsyncRequestSupersedesOlderRequest() async throws {
        let coordinator = FontFilterCoordinator(
            backgroundThreshold: 0,
            compute: { request in
                if request.fonts.first?.id == "old" {
                    Thread.sleep(forTimeInterval: 0.08)
                }
                return FontFilterEngine.ComputeOutput(
                    fonts: request.fonts,
                    coverageCacheUpdates: [:]
                )
            }
        )
        var applied: [String] = []
        coordinator.apply(request(fonts: [font("old")], epoch: 1)) {
            applied.append(contentsOf: $0.fonts.map(\.id))
        }
        coordinator.apply(request(fonts: [font("new")], epoch: 2)) {
            applied.append(contentsOf: $0.fonts.map(\.id))
        }

        try await Task.sleep(nanoseconds: 140_000_000)
        XCTAssertEqual(applied, ["new"])
    }

    func testInvalidateCancelsAsyncCommit() async throws {
        let coordinator = FontFilterCoordinator(
            backgroundThreshold: 0,
            compute: { request in
                Thread.sleep(forTimeInterval: 0.05)
                return FontFilterEngine.ComputeOutput(
                    fonts: request.fonts,
                    coverageCacheUpdates: [:]
                )
            }
        )
        var didApply = false
        coordinator.apply(request(fonts: [font("old")])) { _ in didApply = true }
        coordinator.invalidate()

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(didApply)
    }

    private func request(fonts: [FontItem], epoch: Int = 1) -> FontFilterCoordinator.Request {
        FontFilterCoordinator.Request(
            signature: signature(epoch: epoch),
            fonts: fonts,
            fontsByID: Dictionary(uniqueKeysWithValues: fonts.map { ($0.id, $0) }),
            searchIndex: [:],
            favoriteIDs: [],
            recentIDs: [],
            inputs: FontFilterEngine.Inputs(
                preparedQuery: SearchMatcher.prepare(query: ""),
                coverageQuery: "",
                selectedSource: nil,
                selectedStyle: nil,
                sidebarFilter: .all,
                sortOption: .familyName,
                language: .english,
                showSystemAliasFonts: true,
                scoreWeights: .default,
                managedFontIDs: [],
                manualCollectionFontIDs: nil,
                tagFilterFontIDs: nil,
                fontHealthFontIDs: nil,
                familyWeightCoverage: nil,
                coverageSupportCache: [:]
            )
        )
    }

    private func signature(epoch: Int) -> FontFilterSignature {
        FontFilterSignature(
            searchQuery: "",
            coverageQuery: "",
            selectedSource: nil,
            selectedStyle: nil,
            sidebarFilter: .all,
            sortOption: .familyName,
            language: .english,
            showSystemAliasFonts: true,
            catalogEpoch: epoch,
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

    private func font(_ id: String) -> FontItem {
        .sample(id: id, familyName: id, source: .user, styleTags: [])
    }
}
