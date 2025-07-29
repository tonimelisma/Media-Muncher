//
//  LogEntry.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation

struct LogEntry: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let metadata: [String: String]? // Optional dictionary for extra context

    enum LogLevel: String, Codable, CaseIterable, Identifiable {
        case debug = "DEBUG"
        case info = "INFO"
        case error = "ERROR"

        var id: String { self.rawValue }
    }
}