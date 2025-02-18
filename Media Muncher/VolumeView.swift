//
//  VolumeView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/14/25.
//

import SwiftUI

struct VolumeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(
            selection: Binding(
                get: { appState.selectedVolume },
                set: appState.selectVolume
            )
        ) {
            Section(
                header:
                    HStack {
                        Text("DEVICES")
                        if appState.volumes.count == 0 {
                            Spacer()
                            Image(systemName: "0.square")
                        }
                    }
            ) {
                ForEach(appState.volumes) { volume in
                    HStack {
                        Image(systemName: "sdcard")
                            .foregroundColor(.blue)
                        Text("\(volume.name)")
                        Spacer()
                        Button {
                            appState.ejectVolume(volume)
                        } label: {
                            Image(systemName: "eject.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .tag(volume.id)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .onAppear {
            print("Volume list appeared")
            appState.volumes = appState.loadVolumes()
            appState.ensureVolumeSelection()
        }
    }
}
