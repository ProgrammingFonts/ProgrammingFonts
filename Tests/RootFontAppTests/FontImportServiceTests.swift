import Foundation
import XCTest
@testable import RootFontApp

final class FontImportServiceTests: XCTestCase {
    func testRegisterFontsSkipsUnsupportedExtensions() {
        let urls = [
            URL(fileURLWithPath: "/tmp/one.ttf"),
            URL(fileURLWithPath: "/tmp/two.otf"),
            URL(fileURLWithPath: "/tmp/readme.txt")
        ]
        let registered = LockedURLCollector()
        let service = FontImportService { url in
            registered.append(url)
            return true
        }

        let count = service.registerFonts(at: urls)

        XCTAssertEqual(count, 2)
        XCTAssertEqual(registered.snapshot.map(\.lastPathComponent), ["one.ttf", "two.otf"])
    }

    func testRegisterFontsCountsOnlySuccessfulRegistrations() {
        let urls = [
            URL(fileURLWithPath: "/tmp/one.ttf"),
            URL(fileURLWithPath: "/tmp/two.otf")
        ]
        let service = FontImportService { url in
            url.lastPathComponent == "one.ttf"
        }

        let count = service.registerFonts(at: urls)

        XCTAssertEqual(count, 1)
    }
}

private final class LockedURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    var snapshot: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }
}
