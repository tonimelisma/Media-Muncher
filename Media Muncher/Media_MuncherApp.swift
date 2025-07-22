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
    
    // Centralized dependency injection container
    private let container: AppContainer

    @MainActor
    init() {
        // Initialize the dependency injection container
        container = AppContainer()
        
        // Create AppState with all dependencies injected from container
        let state = AppState(
            logManager: container.logManager,
            volumeManager: container.volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: container.settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: container.fileStore
        )
        _appState = StateObject(wrappedValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(container.volumeManager)
                .environmentObject(container.settingsStore)
                .environmentObject(container.fileStore)
        }
        .commands {
            // This adds a "Settings" menu item to the app menu
        }

        Settings {
            SettingsView()
                .environmentObject(container.settingsStore)
                .environmentObject(container.volumeManager)
        }
    }
}
