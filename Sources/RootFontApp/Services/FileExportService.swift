import Foundation

enum FileExportService {
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
