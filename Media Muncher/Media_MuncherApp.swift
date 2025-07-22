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
    @StateObject private var fileStore: FileStore
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var volumeManager: VolumeManager
    
    init() {
        // Use the blocking factory method to synchronously create the container
        let container = AppContainer.blocking()
        
        // Extract services for StateObject initialization
        let fileStore = container.fileStore
        let settingsStore = container.settingsStore
        let volumeManager = container.volumeManager
        
        let appState = AppState(
            logManager: container.logManager,
            volumeManager: volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: fileStore
        )
        
        // Initialize StateObjects with the created services
        _appState = StateObject(wrappedValue: appState)
        _fileStore = StateObject(wrappedValue: fileStore)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _volumeManager = StateObject(wrappedValue: volumeManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(volumeManager)
                .environmentObject(settingsStore)
                .environmentObject(fileStore)
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
