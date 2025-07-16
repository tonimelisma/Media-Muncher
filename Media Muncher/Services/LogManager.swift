//
//  LogManager.swift
//  Media Muncher
//
//  Custom JSON-based logging system with session-based file storage
//

import Foundation

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    private let logQueue = DispatchQueue(label: "com.mediamuncher.logging", qos: .utility)
    let logFileURL: URL
    
    private init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let logDirectoryURL = homeURL.appendingPathComponent("Library/Logs/Media Muncher")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        
        let timestamp = LogManager.generateTimestamp()
        self.logFileURL = logDirectoryURL.appendingPathComponent("media-muncher-\(timestamp).log")
    }
    
    /// Generates a filesystem-safe timestamp string in format: YYYY-MM-DD_HH-mm-ss
    private static func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    // MARK: - Static convenience methods
    
    static func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        shared.write(level: .debug, category: category, message: message, metadata: metadata, completion: completion)
    }
    
    static func info(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        shared.write(level: .info, category: category, message: message, metadata: metadata, completion: completion)
    }
    
    static func error(_ message: String, category: String = "General", metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        shared.write(level: .error, category: category, message: message, metadata: metadata, completion: completion)
    }
    
    // MARK: - Core logging methods
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]? = nil, completion: (() -> Void)? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message, metadata: metadata)
        
        logQueue.async {
            self.writeToFile(entry)
            completion?()
        }
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write("\n".data(using: .utf8)!)
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // Create new file
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
    
    // MARK: - Test support
    
    func getLogFileContents() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }
}