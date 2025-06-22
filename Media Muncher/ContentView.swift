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
                HStack {
                    if appState.state == programState.enumeratingFiles {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("\(appState.filesScanned) files")
                            .font(.caption)
                            .padding(.leading, 4)
                        Button("Stop") {
                            appState.cancelEnumeration()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    }
                    ErrorView()
                    Spacer()
                    Button("Import") {
                        Task {
                            await appState.importFiles()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .quinaryLabel))
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
        .environmentObject(AppState())
}
