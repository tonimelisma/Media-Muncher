import Foundation

/// Represents an item in the file system (file or directory)
protocol FileSystemItem: Identifiable {
    var id: UUID { get }
    var path: String { get }
    var name: String { get }
}

/// Represents a media file in the file system
struct MediaFile: FileSystemItem, Equatable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let mediaType: MediaType
    let fileType: FileType
    let timeTaken: Date

    static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a directory in the file system
struct Directory: FileSystemItem {
    let id = UUID()
    let path: String
    let name: String
    var children: [any FileSystemItem]
}

/// Enum representing different types of media
enum MediaType: Equatable {
    case processedPicture
    case rawPicture
    case video
    case audio
}

/// Enum representing different file types
enum FileType: Equatable {
    case jpeg
    case png
    case gif
    case mp4
    case mov
    case mp3
    case wav
    // Add more file types as needed
}
