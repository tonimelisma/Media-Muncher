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
            // UI debug logging removed as part of LogManager dependency injection refactoring
        }
        .onChange(of: appState.selectedVolume) { newValue in
            // UI debug logging removed as part of LogManager dependency injection refactoring
        }
        .onChange(of: appState.files.count) { newValue in
            // UI debug logging removed as part of LogManager dependency injection refactoring
        }
        .onChange(of: appState.state) { newValue in
            // UI debug logging removed as part of LogManager dependency injection refactoring
        }
    }
}
