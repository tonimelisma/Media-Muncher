import SwiftUI

struct VolumeView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        List(selection: $viewModel.selectedVolumeID) {
            Section(header: Text("REMOVABLE VOLUMES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 8)) {
                ForEach(viewModel.volumes) { volume in
                    HStack(spacing: 8) {
                        Image(systemName: "sdcard.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(volume.name)
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            print("VolumeView: Eject button tapped for volume: \(volume.name)")
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
                    .onTapGesture {
                        print("VolumeView: Volume tapped: \(volume.name)")
                        viewModel.selectVolume(withID: volume.id)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .onAppear {
            print("VolumeView: View appeared")
            print("VolumeView: Volumes count - \(viewModel.volumes.count)")
            print("VolumeView: Selected volume ID - \(viewModel.selectedVolumeID ?? "None")")
        }
    }

    private func ejectVolume(_ volume: Volume) {
        print("VolumeView: Attempting to eject volume: \(volume.name)")
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            print("VolumeView: Successfully ejected volume: \(volume.name)")
            viewModel.refreshVolumes()
        } catch {
            print("VolumeView: Error ejecting volume: \(volume.name) - \(error.localizedDescription)")
        }
    }
}

struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeView(viewModel: ContentViewModel())
    }
}
