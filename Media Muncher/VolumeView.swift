import SwiftUI

struct VolumeView: View {
    @Binding var volumes: [Volume]
    @Binding var selectedVolumeID: String?

    var body: some View {
        List(selection: $selectedVolumeID) {
            Section(header: Text("REMOVABLE VOLUMES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 8)) {
                ForEach(volumes) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            ejectVolume(volume)
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

    private func ejectVolume(_ volume: Volume) {
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            if let index = volumes.firstIndex(where: { $0.id == volume.id }) {
                volumes.remove(at: index)
            }
            if selectedVolumeID == volume.id {
                selectedVolumeID = volumes.first?.id
            }
        } catch {
            print("Error ejecting volume: \(error.localizedDescription)")
        }
    }
}

struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeView(volumes: .constant([]), selectedVolumeID: .constant(nil))
    }
}
