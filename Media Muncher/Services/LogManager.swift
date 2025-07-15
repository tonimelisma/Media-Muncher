//
//  LogManager.swift
//  Media Muncher
//
//  Custom JSON-based logging system with file rotation and in-memory storage
//

import Foundation

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    private let logQueue = DispatchQueue(label: "com.mediamuncher.logging", qos: .utility)
    let logFileURL: URL
    
    @Published var entries: [LogEntry] = []
    
    private init() {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let logDirectoryURL = homeURL.appendingPathComponent("Library/Logs/Media Muncher")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)
        
        self.logFileURL = logDirectoryURL.appendingPathComponent("media-muncher.log")
        
        // Load existing entries
        loadEntries()
    }
    
    // MARK: - Static convenience methods
    
    static func debug(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        shared.write(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    static func info(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        shared.write(level: .info, category: category, message: message, metadata: metadata)
    }
    
    static func error(_ message: String, category: String = "General", metadata: [String: String]? = nil) {
        shared.write(level: .error, category: category, message: message, metadata: metadata)
    }
    
    // MARK: - Core logging methods
    
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: [String: String]? = nil) {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message, metadata: metadata)
        
        logQueue.async {
            self.writeToFile(entry)
            
            DispatchQueue.main.async {
                self.entries.append(entry)
                self.trimEntriesIfNeeded()
            }
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
            var initialData = data
            initialData.append("\n".data(using: .utf8)!)
            try? initialData.write(to: logFileURL, options: .atomic)
        }
    }
    
    private func loadEntries() {
        logQueue.async {
            guard FileManager.default.fileExists(atPath: self.logFileURL.path),
                  let fileContent = try? String(contentsOf: self.logFileURL, encoding: .utf8) else {
                return
            }
            
            let lines = fileContent.components(separatedBy: .newlines)
            let entries = lines.compactMap { line -> LogEntry? in
                guard !line.isEmpty,
                      let data = line.data(using: .utf8),
                      let entry = try? JSONDecoder().decode(LogEntry.self, from: data) else {
                    return nil
                }
                return entry
            }
            
            DispatchQueue.main.async {
                self.entries = entries
                self.trimEntriesIfNeeded()
            }
        }
    }
    
    private func trimEntriesIfNeeded() {
        if entries.count > 1000 {
            entries = Array(entries.suffix(1000))
        }
    }
    
    func clearLogs() {
        logQueue.async {
            try? FileManager.default.removeItem(at: self.logFileURL)
            
            DispatchQueue.main.async {
                self.entries.removeAll()
            }
        }
    }
    
    // MARK: - Test support
    
    func getLogFileContents() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }
}