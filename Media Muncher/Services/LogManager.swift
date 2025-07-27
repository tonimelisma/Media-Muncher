//
//  LogManager.swift
//  Media Muncher
//
//  Custom JSON-based logging system with session-based file storage
//

import Foundation

actor LogManager: Logging, @unchecked Sendable {
    // Location of the log file for this process lifetime (constant)
    nonisolated let logFileURL: URL

    init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let logDirectoryURL = homeURL.appendingPathComponent("Library/Logs/Media Muncher")
        // Create directory if it doesn't exist (best-effort)
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)

        // Prune logs >30 days old
        LogManager.pruneLogs(olderThan: 30 * 24 * 3600, in: logDirectoryURL)

        let timestamp = LogManager.generateTimestamp()
        let pid = getpid()
        self.logFileURL = logDirectoryURL.appendingPathComponent("media-muncher-\(timestamp)-\(pid).log")
    }
    
    /// Generates a filesystem-safe timestamp string in format: YYYY-MM-DD_HH-mm-ss
    private static func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
        // MARK: - Core logging methods
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]? = nil) async {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message, metadata: metadata)
        self.internalWrite(entry)
    }

    // MARK: – Actor-isolated implementation
    private func internalWrite(_ entry: LogEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                if fileHandle.offsetInFile > 0 {
                    fileHandle.write("\n".data(using: .utf8)!)
                }
                fileHandle.write(data)
                fileHandle.synchronizeFile() // Ensure bytes hit disk before completion
                try? fileHandle.close()
            }
        } else {
            // For first write, don't add leading newline
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    // MARK: - Test support
    nonisolated func getLogFileContents() -> String? {
        try? String(contentsOf: logFileURL, encoding: .utf8)
    }

    /// Removes log files older than `age` seconds.
    private static func pruneLogs(olderThan age: TimeInterval, in dir: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let threshold = Date().addingTimeInterval(-age)
        for url in files where url.lastPathComponent.hasPrefix("media-muncher-") {
            if let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, mtime < threshold {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}