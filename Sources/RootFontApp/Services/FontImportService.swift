import CoreText
import Foundation

protocol FontImportServiceProtocol: Sendable {
    @discardableResult
    func registerFonts(at urls: [URL]) -> Int
}

struct FontImportService: FontImportServiceProtocol {
    @discardableResult
    func registerFonts(at urls: [URL]) -> Int {
        var success = 0
        for url in urls {
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                success += 1
            } else {
                _ = error?.takeRetainedValue()
            }
        }
        return success
    }
}
