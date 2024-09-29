import SwiftUI

struct VolumesView: View {
    @StateObject var viewModel = VolumesViewModel()
    @EnvironmentObject var coordinator: Coordinator
    
    var body: some View {
        NavigationView {
            List(viewModel.volumes) { volume in
                VolumeRow(volume: volume)
            }
            .navigationTitle("Volumes")
        }
        .onAppear {
            viewModel.loadVolumes()
        }
    }
}

struct VolumeRow: View {
    let volume: Volume
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(volume.name)
                .font(.headline)
            Text("Device Path: \(volume.devicePath)")
            Text("Total Size: \(ByteCountFormatter.string(fromByteCount: volume.totalSize, countStyle: .file))")
            Text("Free Size: \(ByteCountFormatter.string(fromByteCount: volume.freeSize, countStyle: .file))")
            Text("Used Size: \(ByteCountFormatter.string(fromByteCount: volume.usedSize, countStyle: .file))")
            Text("Removable: \(volume.isRemovable ? "Yes" : "No")")
            Text("Volume UUID: \(volume.volumeUUID)")
        }
        .padding(.vertical, 8)
    }
}

struct VolumesView_Previews: PreviewProvider {
    static var previews: some View {
        VolumesView()
            .environmentObject(Coordinator(settings: Settings()))
    }
}
