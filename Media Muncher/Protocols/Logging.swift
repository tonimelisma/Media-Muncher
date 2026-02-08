//
//  Logging.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation

protocol Logging: Sendable {
    /// Core log writing call.  The call must be safe to invoke from any thread.
    /// - Parameters:
    ///   - level: Log level.
    ///   - category: Logical category.
    ///   - message: Human-readable message.
    ///   - metadata: Optional structured metadata.
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?) async
}

extension Logging {
    func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil) async {
        await write(level: .debug, category: category, message: message, metadata: metadata)
    }

    func info(_ message: String, category: String = "General", metadata: [String: String]? = nil) async {
        await write(level: .info, category: category, message: message, metadata: metadata)
    }

    func error(_ message: String, category: String = "General", metadata: [String: String]? = nil) async {
        await write(level: .error, category: category, message: message, metadata: metadata)
    }

    // MARK: - Synchronous Fire-and-Forget Helpers
    // Use these from non-async contexts (e.g. @MainActor didSet, Combine sinks)
    // to avoid wrapping every log call in `Task { await ... }`.

    nonisolated func debugSync(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        Task { await write(level: .debug, category: category, message: message, metadata: metadata) }
    }

    nonisolated func infoSync(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        Task { await write(level: .info, category: category, message: message, metadata: metadata) }
    }

    nonisolated func errorSync(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        Task { await write(level: .error, category: category, message: message, metadata: metadata) }
    }
} 