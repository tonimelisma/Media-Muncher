//
//  VolumeView.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
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
                    .accessibilityIdentifier("noVolumesLabel")
            } else {
                List(selection: $appState.selectedVolumeID) {
                    Section(header: Text("Devices")) {
                        ForEach(volumeManager.volumes) { volume in
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                Text(volume.name)
                                Spacer()
                                Button(action: {
                                    try? volumeManager.ejectVolume(volume)
                                }) {
                                    Image(systemName: "eject.circle.fill")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .tag(volume.id)
                        }
                    }
                }
                .accessibilityIdentifier("volumeList")
            }
        }
        .onAppear {
            appState.ensureVolumeSelection()
        }
    }
}

#if DEBUG
#Preview("No Volumes") {
    VolumeView()
        .environmentObject(PreviewHelpers.appState())
        .environmentObject(PreviewHelpers.volumeManager())
}
#endif
