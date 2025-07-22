//
//  MediaView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/16/25.
//

import SwiftUI

struct MediaView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fileStore: FileStore
    
    var body: some View {
        if appState.selectedVolumeID == nil {
            VStack {
                Spacer()
                Text("Select a volume from the sidebar to begin scanning for media files.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else if fileStore.files.isEmpty && appState.state != .enumeratingFiles {
            VStack {
                Spacer()
                Text("No media files found on this volume.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Looking for: Photos, Videos, Audio, and RAW files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        } else {
            MediaFilesGridView()
        }
    }
}
