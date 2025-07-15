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
            LogManager.debug("onAppear", category: "MediaView", metadata: [
                "selectedVolume": appState.selectedVolume ?? "nil",
                "filesCount": "\(appState.files.count)",
                "state": "\(appState.state)"
            ])
        }
        .onChange(of: appState.selectedVolume) { newValue in
            LogManager.debug("selectedVolume changed", category: "MediaView", metadata: ["newValue": newValue ?? "nil"])
        }
        .onChange(of: appState.files.count) { newValue in
            LogManager.debug("files.count changed", category: "MediaView", metadata: ["newValue": "\(newValue)"])
        }
        .onChange(of: appState.state) { newValue in
            LogManager.debug("state changed", category: "MediaView", metadata: ["newValue": "\(newValue)"])
        }
    }
}
