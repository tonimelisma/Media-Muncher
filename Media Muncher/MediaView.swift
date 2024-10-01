import SwiftUI

struct MediaView: View {
    let volume: Volume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume Information:")
                    .font(.headline)
                Text("Name: \(volume.name)")
                Text("Path: \(volume.devicePath)")
                Text("UUID: \(volume.volumeUUID)")
                Text("Total Size: \(ByteCountFormatter.string(fromByteCount: volume.totalSize, countStyle: .file))")
                Text("Free Size: \(ByteCountFormatter.string(fromByteCount: volume.freeSize, countStyle: .file))")
            }
            .padding()
        }
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        MediaView(volume: Volume(id: "1", name: "Test Volume", devicePath: "/Volumes/Test", totalSize: 1000000000, freeSize: 500000000, volumeUUID: "123456"))
    }
}
