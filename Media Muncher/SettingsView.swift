//
//  SettingsView.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/20/25.
//

import SwiftUI

struct FolderPickerView: View {
    let title: String
    @Binding var selectedFolder: String
    @State private var customFolder: String?

    let presetFolders: [(name: String, url: URL)] = [
        ("Pictures", FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!),
        ("Desktop", FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!),
        ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!),
        ("Movies", FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!),
        ("Music", FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!),
        ("Downloads", FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!),
    ]

    var folderOptions: [(name: String, path: String)] {
        var options = presetFolders.map { ($0.name, $0.url.path) }
        if let customFolder = customFolder {
            options.append((URL(fileURLWithPath: customFolder).lastPathComponent, customFolder))
        }
        options.append(("Other…", "other"))
        return options
    }

    var body: some View {
        Picker(
            title,
            selection: Binding(
                get: { self.selectedFolder },
                set: { newValue in
                    if newValue == "other" {
                        selectCustomFolder()
                    } else {
                        selectFolder(newValue)
                    }
                }
            )
        ) {
            // Preset folders
            ForEach(presetFolders, id: \.url) { folder in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(folder.name)
                    Spacer()
                    if folder.url.path == selectedFolder {
                        Image(systemName: "checkmark")
                    }
                }
                .tag(folder.url.path)
            }

            Divider()

            // Custom folder if selected
            if let customFolder = customFolder {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text(URL(fileURLWithPath: customFolder).lastPathComponent)
                    Spacer()
                    if customFolder == selectedFolder {
                        Image(systemName: "checkmark")
                    }
                }
                .tag(customFolder)

                Divider()
            }

            // "Other..." option
            Text("Other…").tag("other")
        }
        .onAppear {
            loadCustomFolder()
        }
        //.pickerStyle(MenuPickerStyle())
    }

    private func selectFolder(_ path: String) {
        selectedFolder = path
        if !presetFolders.map({ $0.url.path }).contains(path) {
            customFolder = path
            UserDefaults.standard.setValue(path, forKey: "customFolder")
        }
    }

    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            selectFolder(url.path)
        }
    }

    private func loadCustomFolder() {
        if let storedPath = UserDefaults.standard.string(forKey: "customFolder") {
            customFolder = storedPath
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Toggle("Delete originals after import", isOn: $settingsStore.settingDeleteOriginals)
            FolderPickerView(
                title: "Destination Folder",
                selectedFolder: $settingsStore.settingDestinationFolder
            )
        }
        .padding()
        .frame(width: 400)
    }
}
