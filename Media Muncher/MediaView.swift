//
//  MediaView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/16/25.
//

import SwiftUI

struct MediaView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if appState.selectedVolume == nil {
                Spacer()
                Text("Select a volume to begin")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                if appState.files.isEmpty && appState.state != .enumeratingFiles {
                    Spacer()
                    Text("No media files found on this volume.")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    MediaFilesGridView()
                }
            }
        }
        .onAppear {
            print("[MediaView] DEBUG: onAppear - selectedVolume: \(appState.selectedVolume ?? "nil")")
            print("[MediaView] DEBUG: onAppear - files.count: \(appState.files.count)")
            print("[MediaView] DEBUG: onAppear - state: \(appState.state)")
        }
        .onChange(of: appState.selectedVolume) { newValue in
            print("[MediaView] DEBUG: selectedVolume changed to: \(newValue ?? "nil")")
        }
        .onChange(of: appState.files.count) { newValue in
            print("[MediaView] DEBUG: files.count changed to: \(newValue)")
        }
        .onChange(of: appState.state) { newValue in
            print("[MediaView] DEBUG: state changed to: \(newValue)")
        }
    }
}
