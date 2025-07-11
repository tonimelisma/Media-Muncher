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

    // Use the actual user directories, not sandboxed ones
    let presetFolders: [(name: String, url: URL)] = [
        ("Pictures", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")),
        ("Desktop", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")),
        ("Documents", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")),
        ("Movies", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies")),
        ("Music", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music")),
        ("Downloads", URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads"))
    ].compactMap { name, url in
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return (name, url)
    }

    @State private var isShowingFilePicker = false
    @State private var selectedTag: String = "custom"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                // Use Menu instead of Picker for better control
                Menu {
                    ForEach(presetFolders, id: \.url) { folder in
                        Button(action: {
                            print("[FolderPickerView] DEBUG: Selected preset folder: \(folder.name) at \(folder.url.path)")
                            selectedURL = folder.url
                        }) {
                            Text(folder.name)
                        }
                    }
                    
                    Divider()
                    
                    Button("Other...") {
                        print("[FolderPickerView] DEBUG: Other... button pressed")
                        isShowingFilePicker = true
                    }
                } label: {
                    HStack {
                        Text(selectedURL?.lastPathComponent ?? "Choose folder...")
                            .foregroundColor(selectedURL == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let url = selectedURL {
                Text(url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    print("[FolderPickerView] DEBUG: File picker selected: \(url.path)")
                    selectedURL = url
                }
            case .failure(let error):
                print("[FolderPickerView] ERROR: File picker error: \(error)")
            }
        }
        .onAppear {
            print("[FolderPickerView] DEBUG: onAppear - selectedURL = \(selectedURL?.path ?? "nil")")
            print("[FolderPickerView] DEBUG: presetFolders = \(presetFolders.map { "\($0.name): \($0.url.path)" })")
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

                DestinationFolderPicker()
                .environmentObject(settingsStore)
            }
            
            Section(header: Text("Media Types to Scan")) {
                Toggle("Scan for Images", isOn: $settingsStore.filterImages)
                Toggle("Scan for Videos", isOn: $settingsStore.filterVideos)
                Toggle("Scan for Audio", isOn: $settingsStore.filterAudio)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            print("[SettingsView] DEBUG: onAppear - destinationURL = \(settingsStore.destinationURL?.path ?? "nil")")
        }
    }
}
