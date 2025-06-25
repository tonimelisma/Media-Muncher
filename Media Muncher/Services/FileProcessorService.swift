import Foundation
import SwiftUI
import AVFoundation
import QuickLookThumbnailing

actor FileProcessorService {

    func fastEnumerate(
        at rootURL: URL,
        filterImages: Bool,
        filterVideos: Bool,
        filterAudio: Bool
    ) -> [File] {
        var files: [File] = []
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return files
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  !(resourceValues.isDirectory ?? true) else {
                continue
            }
            
            if fileURL.hasDirectoryPath {
                let thumbnailFolderNames: Set<String> = ["thmbnl", ".thumbnails", "misc"]
                if thumbnailFolderNames.contains(fileURL.lastPathComponent.lowercased()) {
                    enumerator.skipDescendants()
                }
                continue
            }

            let mediaType = MediaType.from(filePath: fileURL.path)
            if mediaType == .unknown { continue }

            // Apply filters
            switch mediaType {
            case .image where !filterImages: continue
            case .video where !filterVideos: continue
            case .audio where !filterAudio: continue
            default: break
            }
            
            files.append(File(sourcePath: fileURL.path, mediaType: mediaType, status: .waiting))
        }
        return files
    }

    func processFile(
        _ file: File,
        allFiles: [File],
        destinationURL: URL?,
        settings: SettingsStore,
        fileManager: FileManagerProtocol = FileManager.default
    ) async -> File {
        var newFile = file

        // 1. Enrich with metadata and thumbnail
        let url = URL(fileURLWithPath: newFile.sourcePath)
        let (date, size) = await getFileMetadata(url: url, mediaType: newFile.mediaType)
        newFile.date = date
        newFile.size = size
        newFile.thumbnail = await generateThumbnail(for: url)

        // 2. Source-to-source deduplication
        if let myIndex = allFiles.firstIndex(where: { $0.id == newFile.id }) {
            for i in 0..<myIndex {
                let otherFile = allFiles[i]
                if otherFile.status == .duplicate_in_source { continue }
                if otherFile.date == newFile.date && otherFile.size == newFile.size {
                    newFile.status = .duplicate_in_source
                    return newFile
                }
            }
        }
        
        // 3. Destination and collision resolution
        guard let destRootURL = destinationURL else {
            // If no destination is set, we can't resolve, but we can return the enriched file
            return newFile
        }

        var suffix = 0
        var isUnique = false
        while !isUnique {
            let candidatePath = DestinationPathBuilder.buildFinalDestinationUrl(
                for: newFile,
                in: destRootURL,
                settings: settings,
                fileManager: fileManager,
                suffix: suffix > 0 ? suffix : nil
            )

            // Check against other files in this import session
            let inSessionCollision = allFiles.contains { otherFile in
                guard otherFile.id != newFile.id else { return false } // Don't compare with self
                return otherFile.destPath == candidatePath.path
            }

            // Check if a DIFFERENT file exists at the destination
            var onDiskCollision = false
            if fileManager.fileExists(atPath: candidatePath.path) {
                if await !isSameFile(sourceFile: newFile, destinationURL: candidatePath) {
                    onDiskCollision = true
                } else {
                    // It's the same file, mark as pre-existing
                    newFile.status = .pre_existing
                    newFile.destPath = candidatePath.path
                    isUnique = true // Exit the loop
                }
            }

            if inSessionCollision || onDiskCollision {
                suffix += 1
            } else if !isUnique { // Path is free and it's not a pre-existing case
                newFile.status = .waiting
                newFile.destPath = candidatePath.path
                isUnique = true
            }
        }

        return newFile
    }

    private func isSameFile(sourceFile: File, destinationURL: URL) async -> Bool {
        guard let sourceSize = sourceFile.size, let sourceDate = sourceFile.date else { return false }

        do {
            let destAttr = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let destSize = destAttr[.size] as? Int64 ?? 0
            let destDate = destAttr[.modificationDate] as? Date ?? .distantPast
            
            // Using a 2-second tolerance for dates as before
            return sourceSize == destSize && abs(sourceDate.timeIntervalSince(destDate)) < 2
        } catch {
            return false
        }
    }
    
    private func getFileMetadata(url: URL, mediaType: MediaType) async -> (Date?, Int64?) {
        var mediaDate: Date?
        var size: Int64?

        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
            size = Int64(resourceValues.fileSize ?? 0)

            if mediaType == .video {
                let asset = AVURLAsset(url: url)
                if let creationDate = try? await asset.load(.creationDate), let dateValue = try? await creationDate.load(.dateValue) {
                    mediaDate = dateValue
                }
            } else if mediaType == .image {
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                    let exifMetadata = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
                    let tiffMetadata = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
                    
                    if let dateTimeOriginal = exifMetadata?["DateTimeOriginal"] as? String ?? tiffMetadata?["DateTime"] as? String {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        mediaDate = dateFormatter.date(from: dateTimeOriginal)
                    }
                }
            }
            
            if mediaDate == nil {
                mediaDate = resourceValues.creationDate ?? resourceValues.contentModificationDate
            }
        } catch {
            // Could not get metadata, return nil
        }
        
        return (mediaDate, size)
    }

    private func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Image? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
        guard let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        return Image(nsImage: thumbnail.nsImage)
    }
} 