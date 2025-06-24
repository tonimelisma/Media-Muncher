//
//  SettingsView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/20/25.
//

import SwiftUI

struct FolderPickerView: View {
    let title: String
    @Binding var selectedURL: URL?

    let presetFolders: [(name: String, url: URL)] = [
        ("Pictures", FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first),
        ("Desktop", FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first),
        ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first),
        ("Movies", FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first),
        ("Music", FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first),
        ("Downloads", FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first),
    ].compactMap { (name, url) in
        guard let url = url else { return nil }
        return (name: name, url: url)
    }

    var body: some View {
        Picker(
            title,
            selection: $selectedURL
        ) {
            // Preset folders
            ForEach(presetFolders, id: \.url) { folder in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text(folder.name)
                }
                .tag(Optional(folder.url)) // Tag must match selection type
            }

            Divider()

            // Custom folder if selected and not a preset
            if let customURL = selectedURL, !presetFolders.contains(where: { $0.url == customURL }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text(customURL.lastPathComponent)
                }
                .tag(Optional(customURL)) // Tag must match selection type
            }

            // "Other..." option - represented by a button now
            Button(action: selectCustomFolder) {
                Text("Other…")
            }
        }
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedURL = url
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var volumeManager: VolumeManager

    var body: some View {
        Form {
            // Automation section removed (feature deferred)

            Section(header: Text("Import Options")) {
                Toggle("Delete originals after import", isOn: $settingsStore.settingDeleteOriginals)
                Toggle("Eject volume after successful import", isOn: $settingsStore.settingAutoEject)
            }

            Section(header: Text("File Organization")) {
                Toggle("Organize into date-based folders (YYYY/MM)", isOn: $settingsStore.organizeByDate)
                Toggle("Rename files by date and time", isOn: $settingsStore.renameByDate)

                FolderPickerView(
                    title: "Destination Folder",
                    selectedURL: Binding(
                        get: { settingsStore.destinationURL },
                        set: { newURL in
                            if let url = newURL {
                                settingsStore.setDestination(url: url)
                            }
                        }
                    )
                )
            }
            
            Section(header: Text("Media Types to Scan")) {
                Toggle("Scan for Images", isOn: $settingsStore.filterImages)
                Toggle("Scan for Videos", isOn: $settingsStore.filterVideos)
                Toggle("Scan for Audio", isOn: $settingsStore.filterAudio)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
