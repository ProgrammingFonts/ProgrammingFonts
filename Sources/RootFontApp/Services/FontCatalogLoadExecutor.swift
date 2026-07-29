import Foundation

struct FontCatalogLoadOutcome: Sendable {
    let fonts: [FontItem]?
    let failed: Bool
}

enum FontCatalogLoadExecutor {
    static func execute(
        service: FontCatalogServiceProtocol,
        onPartial: @escaping @Sendable ([FontItem]) -> Void,
        reportProgress: @escaping @Sendable (Double) -> Void
    ) async -> FontCatalogLoadOutcome {
        await Task.detached(priority: .userInitiated) {
            do {
                let fonts = try service.loadFonts(
                    onPartial: onPartial,
                    reportProgress: reportProgress
                )
                return FontCatalogLoadOutcome(fonts: fonts, failed: false)
            } catch {
                return FontCatalogLoadOutcome(fonts: nil, failed: true)
            }
        }.value
    }
}
