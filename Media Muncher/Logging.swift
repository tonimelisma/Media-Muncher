//
//  Logging.swift
//  Media Muncher
//
//  Created by Claude on 7/14/25.
//

import Foundation
import os

/// A centralized place for all of the app's loggers.
///
/// This uses Apple's Unified Logging system, which allows for efficient,
/// configurable logging that can be viewed in Xcode or the Console app.
extension Logger {
    /// The subsystem is the unique identifier for your entire application.
    /// We use the app's bundle identifier to ensure it's unique.
    private static var subsystem: String = Bundle.main.bundleIdentifier ?? "net.melisma.Media-Muncher"

    /// A logger for events related to the main application state and lifecycle.
    static let appState = Logger(subsystem: subsystem, category: "AppState")

    /// A logger for the VolumeManager and disk mount/unmount events.
    static let volumeManager = Logger(subsystem: subsystem, category: "VolumeManager")

    /// A logger for the FileProcessorService during scanning and metadata processing.
    static let fileProcessor = Logger(subsystem: subsystem, category: "FileProcessorService")
      
    /// A logger for the ImportService during the file copy/delete process.
    static let importService = Logger(subsystem: subsystem, category: "ImportService")

    /// A logger for the SettingsStore and user preference changes.
    static let settings = Logger(subsystem: subsystem, category: "SettingsStore")
      
    /// A logger for the RecalculationManager when destination paths change.
    static let recalculation = Logger(subsystem: subsystem, category: "RecalculationManager")
}