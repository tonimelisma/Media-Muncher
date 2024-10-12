import SwiftUI

struct MediaFileView: View {
    let mediaFile: MediaFile
    
    var body: some View {
        VStack {
            Image(systemName: MediaFileUtilities.iconForMediaFile(mediaFile))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(MediaFileUtilities.colorForMediaFile(mediaFile))
            Text(mediaFile.sourceName)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct MediaFileView_Previews: PreviewProvider {
    static var previews: some View {
        MediaFileView(mediaFile: MediaFile(sourcePath: "/path/to/file.jpg", sourceName: "file.jpg", size: 1000000, mediaType: .jpeg, timeTaken: Date()))
    }
}
