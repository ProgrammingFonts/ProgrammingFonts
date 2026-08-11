import CoreText
import Foundation
import os

protocol FontImportServiceProtocol: Sendable {
    @discardableResult
    func registerFonts(at urls: [URL]) -> Int
}

struct FontImportService: FontImportServiceProtocol {
    private let registerAction: @Sendable (URL) -> Bool

    init(registerAction: (@Sendable (URL) -> Bool)? = nil) {
        self.registerAction = registerAction ?? { url in
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !ok {
                _ = error?.takeRetainedValue()
                AppLog.catalog.error("font import failed: \(url.path, privacy: .public)")
            }
            return ok
        }
    }

    @discardableResult
    func registerFonts(at urls: [URL]) -> Int {
        var success = 0
        for url in urls {
            guard Self.isSupportedFontURL(url) else {
                AppLog.catalog.info("skipping unsupported font extension: \(url.path, privacy: .public)")
                continue
            }
            if registerAction(url) {
                success += 1
            }
        }
        if success > 0 {
            AppLog.catalog.info("imported \(success, privacy: .public) font(s)")
        }
        return success
    }

    private static func isSupportedFontURL(_ url: URL) -> Bool {
        let allowedExtensions = ["ttf", "otf", "ttc", "otc", "dfont", "woff", "woff2"]
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }
}
