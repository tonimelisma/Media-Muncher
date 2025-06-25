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
    ContentView()
        .environmentObject(AppState(
            volumeManager: VolumeManager(),
            mediaScanner: FileProcessorService(),
            settingsStore: SettingsStore(),
            importService: ImportService()
        ))
        .environmentObject(VolumeManager())
        .environmentObject(SettingsStore())
}
