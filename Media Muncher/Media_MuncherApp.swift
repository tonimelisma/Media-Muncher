//
//  Media_MuncherApp.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/13/25.
//

import SwiftUI

@main
struct Media_MuncherApp: App {
    @StateObject private var appState: AppState
    
    // Services
    private let logManager: Logging = LogManager() // Create the instance
    private let volumeManager: VolumeManager
    private let fileProcessorService: FileProcessorService
    private let settingsStore: SettingsStore
    private let importService: ImportService
    private let recalculationManager: RecalculationManager

    init() {
        // Initialize services with LogManager dependency
        volumeManager = VolumeManager(logManager: logManager)
        fileProcessorService = FileProcessorService(logManager: logManager)
        settingsStore = SettingsStore(logManager: logManager)
        importService = ImportService(logManager: logManager)
        
        // Initialize RecalculationManager with its dependencies
        recalculationManager = RecalculationManager(
            logManager: logManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore
        )
        
        let state = AppState(
            logManager: logManager,
            volumeManager: volumeManager,
            fileProcessorService: fileProcessorService,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager
        )
        _appState = StateObject(wrappedValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(volumeManager)
                .environmentObject(settingsStore)
        }
        .commands {
            // This adds a "Settings" menu item to the app menu
        }

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(volumeManager)
        }
    }
}
