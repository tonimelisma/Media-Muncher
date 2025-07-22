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
} 