import Foundation
import os

/// Centralized logging for rootfont. Wraps `os.Logger` so callers do not
/// need to repeat subsystem strings and so log categories are stable
/// across the codebase.
enum AppLog {
    private static let subsystem = "com.rootfont.app"

    static let catalog = Logger(subsystem: subsystem, category: "catalog")
    static let activation = Logger(subsystem: subsystem, category: "activation")
    static let preferences = Logger(subsystem: subsystem, category: "preferences")
    static let score = Logger(subsystem: subsystem, category: "score")
    static let filter = Logger(subsystem: subsystem, category: "filter")
    static let search = Logger(subsystem: subsystem, category: "search")
    static let cache = Logger(subsystem: subsystem, category: "cache")
    static let watcher = Logger(subsystem: subsystem, category: "watcher")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let app = Logger(subsystem: subsystem, category: "app")
}
