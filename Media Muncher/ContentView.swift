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
                    if appState.state == .enumeratingFiles {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("\(appState.filesScanned) files")
                            .font(.caption)
                            .padding(.leading, 4)
                        Button("Stop") {
                            appState.cancelScan()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    } else if appState.state == .importingFiles {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: Double(appState.importedBytes), total: Double(appState.totalBytesToImport > 0 ? appState.totalBytesToImport : 1))
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            HStack {
                                Text("\(appState.importedFileCount) / \(appState.totalFilesToImport) files")
                                Spacer()
                                Text(byteCountFormatter.string(fromByteCount: appState.importedBytes) + " / " + byteCountFormatter.string(fromByteCount: appState.totalBytesToImport))
                            }
                            .font(.caption)
                        }
                        Button("Cancel") {
                            appState.cancelImport()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                    }
                    ErrorView()
                    Spacer()
                    if appState.state != .importingFiles {
                        Button("Import") {
                            appState.importFiles()
                        }
                        .disabled(appState.state != .idle || appState.files.isEmpty)
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
        .environmentObject(AppState(
            volumeManager: VolumeManager(),
            mediaScanner: MediaScanner(),
            settingsStore: SettingsStore(),
            importService: ImportService()
        ))
        .environmentObject(VolumeManager())
        .environmentObject(SettingsStore())
}

private let byteCountFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter
}()
