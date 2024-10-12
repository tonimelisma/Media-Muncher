import SwiftUI

struct MediaFilesGridView: View {
    let mediaFiles: [MediaFile]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150))], spacing: 10) {
                ForEach(mediaFiles) { mediaFile in
                    MediaFileView(mediaFile: mediaFile)
                }
            }
            .padding()
        }
    }
}

struct MediaFilesGridView_Previews: PreviewProvider {
    static var previews: some View {
        MediaFilesGridView(mediaFiles: [
            MediaFile(sourcePath: "/path/to/file1.jpg", sourceName: "file1.jpg", size: 1000000, mediaType: .jpeg, timeTaken: Date()),
            MediaFile(sourcePath: "/path/to/file2.mp4", sourceName: "file2.mp4", size: 2000000, mediaType: .mp4, timeTaken: Date())
        ])
    }
}
