import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject var volumesViewModel = VolumesViewModel()
    @EnvironmentObject var settings: Settings
    @State private var selectedVolumeID: String?
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            VolumeListView(
                volumes: volumesViewModel.removableVolumes,
                selectedVolumeID: $selectedVolumeID,
                onEject: volumesViewModel.ejectVolume
            )
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            ZStack {
                Color(NSColor.controlBackgroundColor)

                if let volume = volumesViewModel.removableVolumes.first(where: {
                    $0.id == selectedVolumeID
                }) {
                    MediaSelectionView(volume: volume)
                } else if volumesViewModel.removableVolumes.isEmpty {
                    Text("No volumes found")
                } else {
                    Text("Select a volume")
                }
            }
        }
        .navigationTitle("Media Muncher")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(
                    action: toggleSidebar,
                    label: {
                        Image(systemName: "sidebar.leading")
                    })
            }

            ToolbarItem(placement: .navigation) {
                Text("Media Muncher")
                    .font(.system(size: 15, weight: .semibold))
            }

            ToolbarItem(placement: .automatic) {
                Spacer()
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    volumesViewModel.loadVolumes()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh volumes")
                            .font(.system(size: 13))
                    }
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showSettings = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            print("ContentView appeared")
            volumesViewModel.loadVolumes()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}

struct VolumeListView: View {
    let volumes: [Volume]
    @Binding var selectedVolumeID: String?
    let onEject: (Volume) -> Void

    var body: some View {
        List(selection: $selectedVolumeID) {
            Section(
                header:
                    Text("REMOVABLE VOLUMES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            ) {
                ForEach(volumes) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            onEject(volume)
                            if selectedVolumeID == volume.id {
                                selectedVolumeID = nil
                            }
                        }) {
                            Image(systemName: "eject.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                    .tag(volume.id)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct MediaSelectionView: View {
    let volume: Volume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume Information:")
                    .font(.headline)
                Text("Name: \(volume.name)")
                Text("Path: \(volume.devicePath)")
                Text("UUID: \(volume.volumeUUID)")
                Text(
                    "Total Size: \(ByteCountFormatter.string(fromByteCount: volume.totalSize, countStyle: .file))"
                )
                Text(
                    "Free Size: \(ByteCountFormatter.string(fromByteCount: volume.freeSize, countStyle: .file))"
                )
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Settings())
    }
}
