//
//  VolumeView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/14/25.
//

import SwiftUI

struct VolumeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var volumeManager: VolumeManager

    var body: some View {
        VStack {
            if volumeManager.volumes.isEmpty {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.largeTitle)
                    .padding()
                Text("No removable drives detected.")
                    .font(.headline)
            } else {
                List(selection: $appState.selectedVolume) {
                    Section(header: Text("Devices")) {
                        ForEach(volumeManager.volumes) { volume in
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                Text(volume.name)
                                Spacer()
                                Button(action: {
                                    volumeManager.ejectVolume(volume)
                                }) {
                                    Image(systemName: "eject.circle.fill")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .tag(volume.devicePath)
                        }
                    }
                }
            }
        }
        .onAppear {
            appState.ensureVolumeSelection()
        }
    }
}
