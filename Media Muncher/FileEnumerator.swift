import Foundation

/// `FileEnumerator` is a utility class for enumerating files in a given directory.
class FileEnumerator {
    /// Enumerates files and directories recursively in the specified volume path.
    /// - Parameter volumePath: The path of the volume to enumerate.
    /// - Returns: A `Directory` object representing the root of the enumerated file system.
    static func enumerateFileSystem(for volumePath: String) -> Directory {
        print("FileEnumerator: Enumerating file system for path: \(volumePath)")
        
        func enumerate(path: String) -> [any FileSystemItem] {
            var items: [any FileSystemItem] = []
            let fileManager = FileManager.default
            
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { (url, error) -> Bool in
                    print("FileEnumerator: Error enumerating \(url): \(error.localizedDescription)")
                    return true // Continue enumeration
                }
            ) else {
                print("FileEnumerator: Failed to create enumerator for path: \(path)")
                return items
            }
            
            var fileCount = 0
            var directoryCount = 0
            
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]))
                    let isDirectory = resourceValues.isDirectory ?? false
                    let name = fileURL.lastPathComponent
                    
                    if isDirectory {
                        directoryCount += 1
                        let directory = Directory(path: fileURL.path, name: name, children: enumerate(path: fileURL.path))
                        items.append(directory)
                    } else {
                        fileCount += 1
                        let size = Int64(resourceValues.fileSize ?? 0)
                        let timeTaken = resourceValues.contentModificationDate ?? Date()
                        let mediaType = determineMediaType(fileURL: fileURL)
                        let fileType = determineFileType(fileURL: fileURL)
                        
                        let mediaFile = MediaFile(path: fileURL.path, name: name, size: size, mediaType: mediaType, fileType: fileType, timeTaken: timeTaken)
                        items.append(mediaFile)
                    }
                } catch {
                    print("FileEnumerator: Error getting resource values for \(fileURL.path): \(error.localizedDescription)")
                }
            }
            
            print("FileEnumerator: Enumerated \(fileCount) files and \(directoryCount) directories in \(path)")
            return items
        }
        
        let rootURL = URL(fileURLWithPath: volumePath)
        let rootName = rootURL.lastPathComponent
        let children = enumerate(path: volumePath)
        let rootDirectory = Directory(path: volumePath, name: rootName, children: children)
        print("FileEnumerator: Root directory contains \(rootDirectory.children.count) items")
        return rootDirectory
    }
    
    private static func determineMediaType(fileURL: URL) -> MediaType {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            return .processedPicture
        case "raw", "cr2", "nef", "arw", "dng":
            return .rawPicture
        case "mp4", "mov", "avi", "mkv", "flv", "wmv":
            return .video
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return .audio
        default:
            return .processedPicture // Default case, you might want to handle this differently
        }
    }
    
    private static func determineFileType(fileURL: URL) -> FileType {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "gif":
            return .gif
        case "mp4":
            return .mp4
        case "mov":
            return .mov
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        default:
            return .jpeg // Default case, you might want to handle this differently
        }
    }
}
