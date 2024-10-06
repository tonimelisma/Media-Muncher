import SwiftUI

struct VolumeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {
            Section(header: Text("REMOVABLE VOLUMES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .padding(.top, 8)
            ) {
                List(appState.volumes, id: \.id, selection: $appState.selectedVolumeID) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            print("VolumeView: Eject button tapped for volume: \(volume.name)")
                            do {
                                try VolumeLogic.ejectVolume(volume, appState: appState)
                            } catch {
                                errorMessage = "Failed to eject volume: \(error.localizedDescription)"
                                showingError = true
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
                .listStyle(PlainListStyle())
            }
        }
        .onChange(of: appState.selectedVolumeID) { newID, _ in
            if let id = newID {
                VolumeLogic.selectVolume(withID: id, appState: appState)
            }
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            print("VolumeView: View appeared")
            print("VolumeView: Volumes count - \(appState.volumes.count)")
            print("VolumeView: Selected volume ID - \(appState.selectedVolumeID ?? "None")")
        }
    }
}

struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        appState.volumes = [
            Volume(id: "1", name: "Volume 1", devicePath: "/path/to/volume1", totalSize: 1000000000, freeSize: 500000000, volumeUUID: "UUID1"),
            Volume(id: "2", name: "Volume 2", devicePath: "/path/to/volume2", totalSize: 2000000000, freeSize: 1000000000, volumeUUID: "UUID2"),
            Volume(id: "3", name: "Volume 3", devicePath: "/path/to/volume3", totalSize: 3000000000, freeSize: 1500000000, volumeUUID: "UUID3")
        ]
        appState.selectedVolumeID = "1"
        
        return VolumeView()
            .environmentObject(appState)
    }
}
