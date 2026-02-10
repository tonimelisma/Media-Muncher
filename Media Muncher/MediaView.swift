//
//  MediaView.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
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
                    .accessibilityIdentifier("selectVolumeLabel")
                Spacer()
            }
        } else if fileStore.files.isEmpty && appState.state != .enumeratingFiles {
            VStack {
                Spacer()
                Text("No media files found on this volume.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("noMediaFilesLabel")
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

#if DEBUG
#Preview("No Volume Selected") {
    MediaView()
        .environmentObject(PreviewHelpers.appState())
        .environmentObject(PreviewHelpers.fileStore())
}
#endif
