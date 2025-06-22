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
        if appState.selectedVolume == nil {
            Text("Select a volume to begin")
        } else {
            if appState.files.isEmpty
                && appState.state != .enumeratingFiles
            {
                Text("No media files found on this volume.")
            } else {
                MediaFilesGridView()
            }
        }
    }
}
