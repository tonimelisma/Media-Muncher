//
//  ContentView.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
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
    // Previews now need a container to be created first.
    // We can use a simple struct to manage the async setup.
    struct PreviewWrapper: View {
        @State private var container: AppContainer?

        var body: some View {
            if let container = container {
                ContentView()
                    .environmentObject(container.appState)
                    .environmentObject(container.volumeManager)
                    .environmentObject(container.settingsStore)
                    .environmentObject(container.fileStore)
                    .environment(\.thumbnailCache, container.thumbnailCache)
            } else {
                ProgressView()
                    .task {
                        self.container = AppContainer()
                    }
            }
        }
    }
    return PreviewWrapper()
}
