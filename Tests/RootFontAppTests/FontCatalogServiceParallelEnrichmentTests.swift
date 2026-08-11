import Foundation
import XCTest
@testable import RootFontApp

final class FontCatalogServiceParallelEnrichmentTests: XCTestCase {
    func testEnrichmentInspectsMultipleFontsConcurrently() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let names = ["ParallelA-Regular", "ParallelB-Regular", "ParallelC-Regular", "ParallelD-Regular"]
        let urls = try names.map { name -> URL in
            let url = temp.appendingPathComponent("\(name).ttf")
            try Data("font-\(name)".utf8).write(to: url)
            return url
        }

        let inspector = ConcurrentTrackingInspector()
        let service = FontCatalogService(
            featureInspector: inspector,
            metricsProbe: StubMetricsProbe(),
            scoreManifestStore: ScoreManifestStore(manifestURL: temp.appendingPathComponent("scores.json")),
            fontURLIndex: FontURLIndex(prefetchedURLs: urls)
        )

        _ = try await service.drainFonts()
        XCTAssertGreaterThanOrEqual(inspector.maxInFlight, 2)
        XCTAssertEqual(inspector.inspectCount, names.count)
    }
}

private final class ConcurrentTrackingInspector: FontFeatureInspectorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var inspectCount = 0

    func inspect(postScriptName: String) -> ProgrammingProfile {
        lock.lock()
        inFlight += 1
        inspectCount += 1
        maxInFlight = max(maxInFlight, inFlight)
        lock.unlock()

        Thread.sleep(forTimeInterval: 0.03)

        lock.lock()
        inFlight -= 1
        lock.unlock()
        return ProgrammingProfile.empty.withMonospaced(true)
    }
}

private struct StubMetricsProbe: FontMetricsProbeProtocol {
    func measure(postScriptName: String, isMonospaced: Bool) -> FontMetricsSample? {
        FontMetricsSample(asciiAdvanceVariance: 0.1, uniformWidth: true, confusableDistances: [:])
    }
}

private extension ProgrammingProfile {
    func withMonospaced(_ value: Bool) -> ProgrammingProfile {
        var copy = self
        copy.isMonospaced = value
        return copy
    }
}
