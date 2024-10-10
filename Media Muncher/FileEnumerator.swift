import Foundation

/// `FileEnumerator` is a utility class for enumerating files in a given directory.
class FileEnumerator {
    /// Enumerates files recursively in the specified volume path.
    /// - Parameter volumePath: The path of the volume to enumerate.
    /// - Returns: An array of `MediaFile` objects representing the media files in the volume.
    static func enumerateFileSystem(for volumePath: String) -> [MediaFile] {
        print("FileEnumerator: Enumerating file system for path: \(volumePath)")
        
        var mediaFiles: [MediaFile] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: volumePath),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("FileEnumerator: Error enumerating \(url): \(error.localizedDescription)")
                return true // Continue enumeration
            }
        ) else {
            print("FileEnumerator: Failed to create enumerator for path: \(volumePath)")
            return mediaFiles
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]))
                let isDirectory = resourceValues.isDirectory ?? false
                
                if !isDirectory {
                    if let mediaType = determineMediaType(fileURL: fileURL) {
                        let name = fileURL.lastPathComponent
                        let size = Int64(resourceValues.fileSize ?? 0)
                        let timeTaken = resourceValues.contentModificationDate ?? Date()
                        
                        let mediaFile = MediaFile(path: fileURL.path, name: name, size: size, mediaType: mediaType, timeTaken: timeTaken)
                        mediaFiles.append(mediaFile)
                    }
                }
            } catch {
                print("FileEnumerator: Error getting resource values for \(fileURL.path): \(error.localizedDescription)")
            }
        }
        
        print("FileEnumerator: Enumerated \(mediaFiles.count) media files in \(volumePath)")
        return mediaFiles
    }
    
    private static func determineMediaType(fileURL: URL) -> MediaType? {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "gif":
            return .gif
        case "bmp":
            return .bmp
        case "tiff", "tif":
            return .tiff
        case "heic":
            return .heic
        case "arw":
            return .raw(format: .arw)
        case "cr2", "cr3":
            return .raw(format: .cr2) // Note: cr3 is mapped to cr2 here. You might want to add a separate case for cr3 in RawFormat if needed.
        case "dng":
            return .raw(format: .dng)
        case "nef":
            return .raw(format: .nef)
        case "orf":
            return .raw(format: .orf)
        case "pef":
            return .raw(format: .pef)
        case "raf":
            return .raw(format: .raf)
        case "rw2":
            return .raw(format: .rw2)
        case "srw":
            return .raw(format: .srw)
        case "mp4":
            return .mp4
        case "mov":
            return .mov
        case "avi":
            return .avi
        case "mkv":
            return .mkv
        case "flv":
            return .flv
        case "wmv":
            return .wmv
        case "braw":
            return .rawVideo(format: .braw)
        case "r3d":
            return .rawVideo(format: .r3d)
        case "ari":
            return .rawVideo(format: .arriraw)
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        case "aac":
            return .aac
        case "flac":
            return .flac
        case "ogg":
            return .ogg
        case "m4a":
            return .m4a
        default:
            return nil
        }
    }
}
