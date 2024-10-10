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
    // Images
    case jpeg
    case heif
    case png
    case gif
    case bmp
    case tiff
    
    // Raw Images
    case raw(format: RawFormat)
    
    // Videos
    case mp4
    case mov
    case avi
    case mkv
    case flv
    case wmv
    case webm
    
    // Raw Videos
    case rawVideo(format: RawVideoFormat)
    
    // Audio
    case mp3
    case wav
    case aac
    case flac
    case ogg
    case m4a
    
    var category: MediaCategory {
        switch self {
        case .jpeg, .heif, .png, .gif, .bmp, .tiff:
            return .processedPicture
        case .raw:
            return .rawPicture
        case .mp4, .mov, .avi, .mkv, .flv, .wmv, .webm:
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
    case processedPicture
    case rawPicture
    case video
    case rawVideo
    case audio
}

/// Enum representing different raw picture formats
enum RawFormat: String {
    case arw
    case cr2
    case cr3
    case dng
    case nef
    case orf
    case pef
    case raf
    case rw2
    case srw
}

/// Enum representing different raw video formats
enum RawVideoFormat: String {
    case braw
    case r3d
    case arriraw
}
