import SwiftUI

struct MediaFileUtilities {
    static func iconForMediaFile(_ mediaFile: MediaFile) -> String {
        switch mediaFile.mediaType.category {
        case .processedPicture, .rawPicture:
            return "photo"
        case .video, .rawVideo:
            return "video"
        case .audio:
            return "music.note"
        }
    }
    
    static func colorForMediaFile(_ mediaFile: MediaFile) -> Color {
        switch mediaFile.mediaType.category {
        case .processedPicture, .rawPicture:
            return .blue
        case .video, .rawVideo:
            return .red
        case .audio:
            return .green
        }
    }
}
