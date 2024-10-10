import Foundation

/// Represents a media file in the file system
struct MediaFile: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let mediaType: MediaType
    let timeTaken: Date

    static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Enum representing different types of media
enum MediaType: Equatable {
    // Processed Pictures
    case jpeg, png, gif, bmp, tiff, heic
    
    // Raw Pictures
    case raw(format: RawFormat)
    
    // Videos
    case mp4, mov, avi, mkv, flv, wmv
    
    // Raw Videos
    case rawVideo(format: RawVideoFormat)
    
    // Audio
    case mp3, wav, aac, flac, ogg, m4a
    
    var category: MediaCategory {
        switch self {
        case .jpeg, .png, .gif, .bmp, .tiff, .heic:
            return .processedPicture
        case .raw:
            return .rawPicture
        case .mp4, .mov, .avi, .mkv, .flv, .wmv:
            return .video
        case .rawVideo:
            return .rawVideo
        case .mp3, .wav, .aac, .flac, .ogg, .m4a:
            return .audio
        }
    }
}

/// Enum representing different categories of media
enum MediaCategory {
    case processedPicture, rawPicture, video, rawVideo, audio
}

/// Enum representing different raw picture formats
enum RawFormat: String {
    case arw, cr2, cr3, dng, nef, orf, pef, raf, rw2, srw
}

/// Enum representing different raw video formats
enum RawVideoFormat: String {
    case braw, r3d, arriraw
}
