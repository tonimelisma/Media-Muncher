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
    // Create container on MainActor for preview
    let container = MainActor.assumeIsolated {
        AppContainer()
    }

    return ContentView()
        .environmentObject(AppState(
            logManager: container.logManager,
            volumeManager: container.volumeManager,
            fileProcessorService: container.fileProcessorService,
            settingsStore: container.settingsStore,
            importService: container.importService,
            recalculationManager: container.recalculationManager,
            fileStore: container.fileStore
        ))
        .environmentObject(container.volumeManager) // Keep this line for VolumeView
        .environmentObject(container.settingsStore) // Keep this line for SettingsView
        .environmentObject(container.fileStore) // Add FileStore to environment
}
