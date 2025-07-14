//
//  ContentView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/13/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            VolumeView()
                .navigationSplitViewColumnWidth(min: 150, ideal: 250, max: 250)
        } detail: {
            VStack {
                MediaView()
                Spacer()
                BottomBarView()
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: {
                    openSettings()
                }) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .navigationTitle("Media Muncher")
    }
}

#Preview {
    let volumeManager = VolumeManager()
    let mediaScanner = FileProcessorService() // Keep this line to initialize AppState
    let settingsStore = SettingsStore()
    let importService = ImportService() // Keep this line to initialize AppState
    let recalculationManager = RecalculationManager( // Keep this line to initialize AppState
        fileProcessorService: mediaScanner,
        settingsStore: settingsStore
    )

    return ContentView()
        .environmentObject(AppState(
            volumeManager: volumeManager,
            mediaScanner: mediaScanner,
            settingsStore: settingsStore,
            importService: importService,
            recalculationManager: recalculationManager
        ))
        .environmentObject(volumeManager) // Keep this line for VolumeView
        .environmentObject(settingsStore) // Keep this line for SettingsView
}
