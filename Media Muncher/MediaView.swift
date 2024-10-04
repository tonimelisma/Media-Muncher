import SwiftUI

struct MediaView: View {
    let volume: Volume?
    let volumes: [Volume]
    @Binding var defaultSavePath: String
    @State private var isDirectoryPickerPresented = false

    var body: some View {
        VStack {
            if volumes.isEmpty {
                Text("No removable volumes found")
            } else if let volume = volume {
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
                .background(.white)
            } else {
                Text("Select a volume")
            }

            Spacer()

            HStack {
                Text("Import To:")
                    .font(.system(size: 13, weight: .semibold))

                FolderSelector(
                    defaultSavePath: $defaultSavePath,
                    showAdvancedSettings: true)

                Spacer()

                Button("Import") {
                    // Import action here
                }
                .disabled(volume == nil)
            }
            .padding()
        }
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        MediaView(
            volume: Volume(
                id: "1", name: "Test Volume", devicePath: "/Volumes/Test",
                totalSize: 1_000_000_000, freeSize: 500_000_000,
                volumeUUID: "123456"), volumes: [],
            defaultSavePath: .constant(NSHomeDirectory()))
    }
}
