import Foundation
import XCTest
@testable import RootFontApp

final class FontCatalogServiceWarmLoadTests: XCTestCase {
    func testWarmLoadUsesCachedMetadataWithoutStyleResolver() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let fontURL = temp.appendingPathComponent("WarmMono-Regular.ttf")
        try Data("font".utf8).write(to: fontURL)

        let manifestURL = temp.appendingPathComponent("scores.json")
        let store = ScoreManifestStore(manifestURL: manifestURL)
        let cacheKey = store.cacheKey(for: "WarmMono-Regular", fileURL: fontURL)

        let warmItem = FontItem(
            id: "WarmMono-Regular",
            familyName: "Warm Mono",
            postScriptName: "WarmMono-Regular",
            displayName: "Warm Mono Regular",
            source: .user,
            styleTags: [.regular, .monospace],
            localizedFamilyNames: ["ja": "ウォームモノ"],
            programming: ProgrammingProfile.empty.withMonospaced(true),
            metrics: FontMetricsSample(asciiAdvanceVariance: 0.1, uniformWidth: true, confusableDistances: [:]),
            programmingScore: ProgrammingScore(total: 80, grade: .a, breakdown: [])
        )
        store.save([cacheKey: CachedScoreEntry.from(item: warmItem)])

        let trapResolver = TrapFontStyleResolver()
        let service = FontCatalogService(
            styleResolver: trapResolver,
            scoreManifestStore: store,
            fontURLIndex: FontURLIndex(prefetchedURLs: [fontURL])
        )

        let fonts = try await service.drainFonts()
        XCTAssertEqual(fonts.count, 1)
        XCTAssertEqual(fonts[0].familyName, "Warm Mono")
        XCTAssertEqual(fonts[0].localizedFamilyNames["ja"], "ウォームモノ")
        XCTAssertEqual(fonts[0].programmingScore?.total, 80)
        XCTAssertFalse(trapResolver.wasCalled)
    }
}

private final class TrapFontStyleResolver: FontStyleResolverProtocol, @unchecked Sendable {
    private(set) var wasCalled = false

    func resolveStyleTags(for font: NSFont) -> Set<FontStyleTag> {
        wasCalled = true
        return [.regular]
    }
}

private extension ProgrammingProfile {
    func withMonospaced(_ value: Bool) -> ProgrammingProfile {
        var copy = self
        copy.isMonospaced = value
        return copy
    }
}
