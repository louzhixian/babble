// BabbleApp/Sources/BabbleApp/Services/Logger.swift

import Foundation
import OSLog

/// Centralized logging for Babble app
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.babble.app"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let process = Logger(subsystem: subsystem, category: "process")
    static let download = Logger(subsystem: subsystem, category: "download")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
}
