import SwiftUI

struct MediaView: View {
    let volume: Volume?
    let volumes: [Volume]
    let fileItems: [FileItem]
    @Binding var defaultSavePath: String

    var body: some View {
        VStack {
            if volumes.isEmpty {
                Text("No removable volumes found")
            } else if let volume = volume {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 10) {
                        ForEach(fileItems) { item in
                            VStack {
                                Image(systemName: item.type == "directory" ? "folder" : "doc")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(item.type == "directory" ? .blue : .gray)
                                Text(item.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Volume: \(volume.name)")
                    .font(.headline)
                    .padding(.bottom)
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
                    print("MediaView: Import button tapped")
                    // Import action here
                }
                .disabled(volume == nil)
            }
            .padding()
        }
        .onAppear {
            print("MediaView: View appeared")
            print("MediaView: Volume - \(volume?.name ?? "None")")
            print("MediaView: File items count - \(fileItems.count)")
        }
    }
}

struct MediaView_Previews: PreviewProvider {
    static var previews: some View {
        MediaView(
            volume: Volume(
                id: "1", name: "Test Volume", devicePath: "/Volumes/Test",
                totalSize: 1_000_000_000, freeSize: 500_000_000,
                volumeUUID: "123456"),
            volumes: [],
            fileItems: [],
            defaultSavePath: .constant(NSHomeDirectory())
        )
    }
}
