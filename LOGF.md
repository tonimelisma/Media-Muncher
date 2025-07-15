# **Implementation Plan: Custom Logging Framework**

This document outlines the four phases to build and integrate a custom, file-based JSON logging system into the Media Muncher application.

## **Phase 1: Build the Core Logging Engine**

**Goal:** Create the fundamental components that can write structured log entries to a file.

#### **Step 1.1: Define the Log Structure**

First, we need a model for our log entries. This struct will define what information each log message contains.

1. In Xcode, navigate to the Models group.  
2. Create a new Swift file named LogEntry.swift.  
3. Add the following code:

// Models/LogEntry.swift

import Foundation

struct LogEntry: Codable, Identifiable {  
    var id \= UUID()  
    let timestamp: Date  
    let level: LogLevel  
    let category: String  
    let message: String  
    let metadata: \[String: String\]? // Optional dictionary for extra context

    enum LogLevel: String, Codable, CaseIterable, Identifiable {  
        case debug \= "DEBUG"  
        case info \= "INFO"  
        case error \= "ERROR"

        var id: String { self.rawValue }  
    }  
}

#### **Step 1.2: Create the Log Manager**

Next, we'll create a singleton manager responsible for all log operations: writing to the file, reading from it, and managing its size.

1. In Xcode, navigate to the Services group.  
2. Create a new Swift file named LogManager.swift.  
3. Add the following code. This class will handle the file I/O on a background queue to avoid blocking the UI.

// Services/LogManager.swift

import Foundation  
import Combine

@MainActor  
class LogManager: ObservableObject {  
    @Published private(set) var entries: \[LogEntry\] \= \[\]

    static let shared \= LogManager() // Singleton for global access

    private let logFileURL: URL  
    private let maxFileSize: Int64 \= 5 \* 1024 \* 1024 // 5 MB  
    private let logQueue \= DispatchQueue(label: "net.melisma.mediamuncher.logqueue")

    private init() {  
        guard let appSupportURL \= FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {  
            fatalError("Cannot find Application Support directory.")  
        }

        let logDirectoryURL \= appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MediaMuncher")  
          
        try? FileManager.default.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true, attributes: nil)  
        self.logFileURL \= logDirectoryURL.appendingPathComponent("events.log")  
          
        // Load existing entries when the app starts  
        loadEntries()  
    }

    /// Writes a log entry to the file.  
    func write(level: LogEntry.LogLevel, category: String, message: String, metadata: \[String: String\]? \= nil) {  
        let entry \= LogEntry(timestamp: Date(), level: level, category: category, message: message, metadata: metadata)

        // Update the in-memory store for the UI immediately  
        DispatchQueue.main.async {  
            self.entries.insert(entry, at: 0\)  
        }

        logQueue.async {  
            self.rotateLogsIfNeeded()  
              
            let encoder \= JSONEncoder()  
            encoder.dateEncodingStrategy \= .iso8601  
            guard let data \= try? encoder.encode(entry) else { return }

            if let fileHandle \= try? FileHandle(forWritingTo: self.logFileURL) {  
                defer { fileHandle.closeFile() }  
                fileHandle.seekToEndOfFile()  
                fileHandle.write(data)  
                fileHandle.write("\\n".data(using: .utf8)\!)  
            } else {  
                // If the file doesn't exist, create it  
                try? data.appending("\\n".data(using: .utf8)\!).write(to: self.logFileURL, options: .atomic)  
            }  
        }  
    }

    /// Loads all log entries from the file into memory for the UI.  
    func loadEntries() {  
        logQueue.async {  
            guard let logData \= try? Data(contentsOf: self.logFileURL), \!logData.isEmpty else {  
                return  
            }

            let logLines \= String(decoding: logData, as: UTF8.self)  
                .split(separator: "\\n", omittingEmptySubsequences: true)  
                .map { Data($0.utf8) }

            let decoder \= JSONDecoder()  
            decoder.dateDecodingStrategy \= .iso8601  
            let loadedEntries \= logLines.compactMap { try? decoder.decode(LogEntry.self, from: $0) }

            DispatchQueue.main.async {  
                self.entries \= loadedEntries.sorted(by: { $0.timestamp \> $1.timestamp })  
            }  
        }  
    }  
      
    /// Clears all log entries from memory and the log file.  
    func clearLogs() {  
        logQueue.async {  
            try? FileManager.default.removeItem(at: self.logFileURL)  
            FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil, attributes: nil)  
        }  
        DispatchQueue.main.async {  
            self.entries \= \[\]  
        }  
    }

    private func rotateLogsIfNeeded() {  
        guard let attributes \= try? FileManager.default.attributesOfItem(atPath: logFileURL.path),  
              let size \= attributes\[.size\] as? Int64,  
              size \> maxFileSize else {  
            return  
        }

        let fileManager \= FileManager.default  
        let backupURL \= logFileURL.appendingPathExtension("1")  
          
        try? fileManager.removeItem(at: backupURL)  
        try? fileManager.moveItem(at: logFileURL, to: backupURL)  
    }  
}

## **Phase 2: Integrate the New Logger**

**Goal:** Replace all existing print() and os.Logger calls with the new LogManager.

#### **Step 2.1: Remove Old Logging System**

1. Delete the file Logging.swift from the project. This will cause build errors where the old logger was used, which is exactly what we want. It will guide us to every location we need to update.

#### **Step 2.2: Replace Log Calls**

Go through each file that has a build error and replace the old log call with a new one.  
**Example in AppState.swift:**

* **BEFORE:**  
  Logger.appState.debug("Volume changes received: \\(newVolumes.map { $0.name }, privacy: .public)")

* **AFTER:**  
  LogManager.shared.write(level: .debug, category: "AppState", message: "Volume changes received", metadata: \["volumes": "\\(newVolumes.map { $0.name })"\])

**Example in VolumeManager.swift:**

* **BEFORE:**  
  print("\[VolumeManager\] ERROR: Error getting resource values for volume at \\(url.path): \\(error)")

* **AFTER:**  
  LogManager.shared.write(level: .error, category: "VolumeManager", message: "Error getting resource values for volume", metadata: \["path": url.path, "error": error.localizedDescription\])

**Example in RecalculationManager.swift:**

* **BEFORE:**  
  print("\[RecalculationManager\] DEBUG: startRecalculation called with new destination: \\(newDestinationURL?.path ?? "nil")")

* **AFTER:**  
  LogManager.shared.write(level: .debug, category: "RecalculationManager", message: "startRecalculation called", metadata: \["newDestination": newDestinationURL?.path ?? "nil"\])

**Instructions:** Systematically go through every service and view model file (FileProcessorService, ImportService, SettingsStore, etc.) and replace all print and Logger calls using the pattern above. Use the category parameter to identify the source of the log (e.g., "FileProcessorService").

## **Phase 3: Removed**

Just continue to phase 4.

## **Phase 4: Update Tests and Documentation**

**Goal:** Ensure the new logging system is integrated into the testing workflow and project documentation.

#### **Step 4.1: Update Unit & Integration Tests**

Your existing tests don't need to assert log outputs, but you can now use the log file to debug failing tests from the command line.

1. **Find the Log File:** After a test run, find the log file at \~/Library/Application Support/net.melisma.Media-Muncher/events.log.  
2. **Inspect:** Use cat or a text editor to see the exact sequence of events that led to a test failure. This is incredibly useful for debugging complex integration tests.  
3. **No Code Changes Needed:** For now, no changes to the test code itself are required. The value is in the generated log artifact.

#### **Step 4.2: Update Documentation**

Update ARCHITECTURE.md to reflect the new custom logging system, replacing the section on Unified Logging.

1. **Open ARCHITECTURE.md**.  
2. Remove section 11\. Debugging with Unified Logging.  
3. Add a new section describing the LogManager and the events.log file format (JSON per line) and its location. Explain that this is now the primary method for debugging.