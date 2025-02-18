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
            Text("Please insert a removable volume")
        } else {
            if appState.files.isEmpty
                && appState.state != programState.enumeratingFiles
            {
                Text("No media files found in volume")
            } else {
                MediaFilesGridView()
            }
        }
    }
}
