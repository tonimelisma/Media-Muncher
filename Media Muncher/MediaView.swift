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
            if appState.selectedVolumeID == nil {
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
    }
}
