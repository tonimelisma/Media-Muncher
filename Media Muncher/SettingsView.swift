//
//  SettingsView.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
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
                            .accessibilityIdentifier("organizeByDateToggle")
                        Text("Creates folders in YYYY/MM format.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Toggle("Rename files by date and time", isOn: $settingsStore.renameByDate)
                            .accessibilityIdentifier("renameByDateToggle")
                        Text("Renames files to 'YYYYMMDD_HHMMSS.ext'.")
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
                            .accessibilityIdentifier("filterImagesToggle")
                        Toggle("Videos", isOn: $settingsStore.filterVideos)
                            .accessibilityIdentifier("filterVideosToggle")
                        Toggle("Audio", isOn: $settingsStore.filterAudio)
                            .accessibilityIdentifier("filterAudioToggle")
                        Toggle("RAW", isOn: $settingsStore.filterRaw)
                            .accessibilityIdentifier("filterRawToggle")
                    }
                }

                // Section 4: Import Options
                GridRow {
                    Text("Import:")
                        .gridColumnAlignment(.trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Delete originals after successful import", isOn: $settingsStore.settingDeleteOriginals)
                            .accessibilityIdentifier("deleteOriginalsToggle")
                        Toggle("Eject volume after successful import", isOn: $settingsStore.settingAutoEject)
                            .accessibilityIdentifier("autoEjectToggle")
                    }
                }
            }
            .padding(.horizontal, 100) // Much more generous horizontal padding
        }
        .padding(.vertical, 24) // Slightly less vertical padding above and below
        .frame(width: 600) // Significantly increased width for more horizontal breathing room
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .environmentObject(PreviewHelpers.settingsStore())
        .environmentObject(PreviewHelpers.volumeManager())
}
#endif
