import Foundation

/// `FileEnumerator` is a utility class for enumerating files in a given directory.
class FileEnumerator {
    /// Enumerates files recursively in the specified volume path.
    /// - Parameters:
    ///   - volumePath: The path of the volume to enumerate.
    ///   - appState: The global app state to update with enumerated files.
    static func enumerateFileSystem(for volumePath: String, appState: AppState) async {
        print("FileEnumerator: Enumerating file system for path: \(volumePath)")
        
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: volumePath),
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { (url, error) -> Bool in
                print("FileEnumerator: Error enumerating \(url): \(error.localizedDescription)")
                return true // Continue enumeration
            }
        ) else {
            print("FileEnumerator: Failed to create enumerator for path: \(volumePath)")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set([.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]))
                let isDirectory = resourceValues.isDirectory ?? false
                
                if !isDirectory {
                    if let mediaType = determineMediaType(fileURL: fileURL) {
                        let name = fileURL.lastPathComponent
                        let size = Int64(resourceValues.fileSize ?? 0)
                        let creationDateTime = await MediaMetadataExtractor.extractCreationDateTime(
                            from: fileURL,
                            mediaType: mediaType,
                            fallbackDate: resourceValues.creationDate ?? Date()
                        )
                        
                        let mediaFile = MediaFile(path: fileURL.path, name: name, size: size, mediaType: mediaType, timeTaken: creationDateTime)
                        
                        print("FileEnumerator: File: \(name), Type: \(mediaType), DateTime: \(dateFormatter.string(from: creationDateTime))")
                        
                        await MainActor.run {
                            appState.mediaFiles.append(mediaFile)
                        }
                    }
                }
            } catch {
                print("FileEnumerator: Error getting resource values for \(fileURL.path): \(error.localizedDescription)")
            }
        }
        
        print("FileEnumerator: Enumerated \(appState.mediaFiles.count) media files in \(volumePath)")
    }
    
    private static func determineMediaType(fileURL: URL) -> MediaType? {
        let pathExtension = fileURL.pathExtension.lowercased()
        switch pathExtension {
        // Processed Pictures
        case "jpg", "jpeg", "jpe", "jif", "jfif", "jfi":
            return .jpeg
        case "jp2", "j2k", "jpf", "jpm", "jpg2", "j2c", "jpc", "jpx", "mj2":
            return .jpeg2000
        case "jxl":
            return .jpegXL
        case "png":
            return .png
        case "gif":
            return .gif
        case "bmp":
            return .bmp
        case "tiff", "tif":
            return .tiff
        case "psd":
            return .psd
        case "eps":
            return .eps
        case "svg":
            return .svg
        case "ico":
            return .ico
        case "webp":
            return .webp
        case "heif", "heifs", "heic", "heics", "avci", "avcs", "hif":
            return .heif
        // Raw Pictures
        case "arw":
            return .raw(format: .arw)
        case "cr2":
            return .raw(format: .cr2)
        case "cr3":
            return .raw(format: .cr3)
        case "crw":
            return .raw(format: .crw)
        case "dng":
            return .raw(format: .dng)
        case "erf":
            return .raw(format: .erf)
        case "kdc":
            return .raw(format: .kdc)
        case "mrw":
            return .raw(format: .mrw)
        case "nef":
            return .raw(format: .nef)
        case "orf":
            return .raw(format: .orf)
        case "pef":
            return .raw(format: .pef)
        case "raf":
            return .raw(format: .raf)
        case "raw":
            return .raw(format: .raw)
        case "rw2":
            return .raw(format: .rw2)
        case "sr2":
            return .raw(format: .sr2)
        case "srf":
            return .raw(format: .srf)
        case "x3f":
            return .raw(format: .x3f)
        // Video Files
        case "mp4":
            return .mp4
        case "avi":
            return .avi
        case "mov":
            return .mov
        case "wmv":
            return .wmv
        case "flv":
            return .flv
        case "mkv":
            return .mkv
        case "webm":
            return .webm
        case "ogv":
            return .ogv
        case "m4v":
            return .m4v
        case "3gp":
            return .threegp
        case "3g2":
            return .threeg2
        case "asf":
            return .asf
        case "vob":
            return .vob
        case "mts", "m2ts":
            return .mts
        // Raw Videos
        case "braw":
            return .rawVideo(format: .braw)
        case "r3d":
            return .rawVideo(format: .r3d)
        case "ari":
            return .rawVideo(format: .arriraw)
        // Audio Files
        case "mp3":
            return .mp3
        case "wav":
            return .wav
        case "ogg":
            return .ogg
        case "flac":
            return .flac
        case "aac":
            return .aac
        case "m4a":
            return .m4a
        case "wma":
            return .wma
        case "amr":
            return .amr
        case "ac3":
            return .ac3
        case "dts":
            return .dts
        case "alac":
            return .alac
        case "ape":
            return .ape
        case "shn":
            return .shn
        case "tta":
            return .tta
        default:
            return nil
        }
    }
}
