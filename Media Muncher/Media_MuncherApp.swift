//
//  Media_MuncherApp.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/13/25.
//

import SwiftUI

@main
struct Media_MuncherApp: App {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var volumeManager = VolumeManager()
    private var mediaScanner = MediaScanner()
    @StateObject private var appState: AppState

    init() {
        let settings = SettingsStore()
        let volumes = VolumeManager()
        let scanner = MediaScanner()
        _settingsStore = StateObject(wrappedValue: settings)
        _volumeManager = StateObject(wrappedValue: volumes)
        _appState = StateObject(wrappedValue: AppState(volumeManager: volumes, mediaScanner: scanner, settingsStore: settings))
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
        }
    }
}
