//
//  ErrorView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/21/25.
//

import SwiftUI

struct ErrorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if(appState.error != errorState.none) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title)
                .foregroundColor(.red)
            if appState.error == errorState.destinationFolderNotWritable {
                Text("Destination folder not writable")
            }
        }
    }
}
