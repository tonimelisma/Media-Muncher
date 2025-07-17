import Foundation

protocol Logging: Sendable {
    /// Core log writing call.  The call must be safe to invoke from any thread.
    /// - Parameters:
    ///   - level: Log level.
    ///   - category: Logical category.
    ///   - message: Human-readable message.
    ///   - metadata: Optional structured metadata.
    ///   - completion: Optional completion invoked **after** the entry has been persisted.
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]?, completion: (@Sendable () -> Void)?)
}

extension Logging {
    func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .debug, category: category, message: message, metadata: metadata, completion: completion)
    }

    func info(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .info, category: category, message: message, metadata: metadata, completion: completion)
    }

    func error(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        write(level: .error, category: category, message: message, metadata: metadata, completion: completion)
    }
} 