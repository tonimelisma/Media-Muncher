//
//  SettingsView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/20/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var volumeManager: VolumeManager

    var body: some View {
        VStack {
            Grid(alignment: .topLeading, verticalSpacing: 24) {
                // Section 1: Destination Picker
                GridRow {
                    Text("Destination:")
                        .gridColumnAlignment(.trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        DestinationFolderPicker()
                            .environmentObject(settingsStore)
                            .frame(maxWidth: 350)
                        
                        if let url = settingsStore.destinationURL {
                            Text(url.path)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                // Section 2: File Organization
                GridRow {
                    Text("Organize:")
                        .gridColumnAlignment(.trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Organize into date-based folders", isOn: $settingsStore.organizeByDate)
                        Text("Creates folders in YYYY/MM format.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Toggle("Rename files by date and time", isOn: $settingsStore.renameByDate)
                        Text("Renames files to 'YYYY-MM-DD at HH.MM.SS.ext'.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                // Section 3: Media Types
                GridRow {
                    Text("Scan for:")
                        .gridColumnAlignment(.trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Images", isOn: $settingsStore.filterImages)
                        Toggle("Videos", isOn: $settingsStore.filterVideos)
                        Toggle("Audio", isOn: $settingsStore.filterAudio)
                    }
                }

                // Section 4: Import Options
                GridRow {
                    Text("Import:")
                        .gridColumnAlignment(.trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Delete originals after successful import", isOn: $settingsStore.settingDeleteOriginals)
                        Toggle("Eject volume after successful import", isOn: $settingsStore.settingAutoEject)
                    }
                }
            }
            .padding(.horizontal, 100) // Much more generous horizontal padding
        }
        .padding(.vertical, 24) // Slightly less vertical padding above and below
        .frame(width: 600) // Significantly increased width for more horizontal breathing room
        .onAppear {
            print("[SettingsView] DEBUG: onAppear - destinationURL = \(settingsStore.destinationURL?.path ?? "nil")")
        }
    }
}
