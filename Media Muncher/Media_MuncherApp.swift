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
        // Use print because LogManager is not yet available.
        print("DEBUG: Media_MuncherApp.init() started - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)")

        // Use the blocking factory method to synchronously create the container
        print("DEBUG: Media_MuncherApp.init() calling AppContainer.blocking()...")
        let container = AppContainer.blocking()
        print("DEBUG: Media_MuncherApp.init() AppContainer.blocking() returned.")
        
        // Extract services for StateObject initialization
        print("DEBUG: Media_MuncherApp.init() extracting services from container...")
        let fileStore = container.fileStore
        let settingsStore = container.settingsStore
        let volumeManager = container.volumeManager
        print("DEBUG: Media_MuncherApp.init() services extracted.")

        print("DEBUG: Media_MuncherApp.init() creating AppState...")
        let appState = AppState(
            logManager: container.logManager,
            volumeManager: volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: fileStore
        )
        print("DEBUG: Media_MuncherApp.init() AppState created.")
        
        // Initialize StateObjects with the created services
        print("DEBUG: Media_MuncherApp.init() initializing StateObjects...")
        _appState = StateObject(wrappedValue: appState)
        _fileStore = StateObject(wrappedValue: fileStore)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _volumeManager = StateObject(wrappedValue: volumeManager)
        print("DEBUG: Media_MuncherApp.init() finished.")
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
