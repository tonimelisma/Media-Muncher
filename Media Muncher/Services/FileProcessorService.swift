import Foundation
import SwiftUI
import AVFoundation
import QuickLookThumbnailing
import CryptoKit // For SHA-256 checksum fallback when date/name heuristics fail
import os

actor FileProcessorService {

    // Thumbnail Cache
    private var thumbnailCache: [String: Image] = [:] // key = file path
    private var thumbnailOrder: [String] = []
    private let thumbnailCacheLimit = 2000
    
    private let fileManager = FileManager.default

    init() {
    }

    func processFiles(
        from sourceURL: URL,
        destinationURL: URL?,
        settings: SettingsStore
    ) async -> [File] {
        Logger.fileProcessor.debug("processFiles called")
        Logger.fileProcessor.debug("sourceURL: \(sourceURL.path, privacy: .public)")
        Logger.fileProcessor.debug("destinationURL: \(destinationURL?.path ?? "nil", privacy: .public)")
        Logger.fileProcessor.debug("filterImages: \(settings.filterImages, privacy: .public)")
        Logger.fileProcessor.debug("filterVideos: \(settings.filterVideos, privacy: .public)")
        Logger.fileProcessor.debug("filterAudio: \(settings.filterAudio, privacy: .public)")
        
        let discoveredFilesUnsorted = fastEnumerate(
            at: sourceURL,
            filterImages: settings.filterImages,
            filterVideos: settings.filterVideos,
            filterAudio: settings.filterAudio
        )
        
        Logger.fileProcessor.debug("fastEnumerate found \(discoveredFilesUnsorted.count, privacy: .public) files")

        // Ensure deterministic processing order so collision suffixes are repeatable across runs/tests
        let discoveredFiles = discoveredFilesUnsorted.sorted { $0.sourcePath < $1.sourcePath }

        var processedFiles: [File] = []
        for file in discoveredFiles {
            Logger.fileProcessor.debug("Processing file: \(file.sourcePath, privacy: .public)")
            let processedFile = await processFile(
                file,
                allFiles: processedFiles,
                destinationURL: destinationURL,
                settings: settings
            )
            processedFiles.append(processedFile)
        }
        
        Logger.fileProcessor.debug("processFiles completed with \(processedFiles.count, privacy: .public) files")
        return processedFiles
    }

    private func fastEnumerate(
        at rootURL: URL,
        filterImages: Bool,
        filterVideos: Bool,
        filterAudio: Bool
    ) -> [File] {
        let sidecarExtensions: Set<String> = ["thm", "xmp", "lrc"]
        var allFileURLs: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        // First, collect all file URLs.
        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true {
                let thumbnailFolderNames: Set<String> = ["thmbnl", ".thumbnails", "misc"]
                if thumbnailFolderNames.contains(fileURL.lastPathComponent.lowercased()) {
                    enumerator.skipDescendants()
                }
                continue
            }
            allFileURLs.append(fileURL)
        }

        var mainFiles: [File] = []
                let _ = Set(allFileURLs)

        for url in allFileURLs {
            let ext = url.pathExtension.lowercased()
            if sidecarExtensions.contains(ext) {
                continue // Skip sidecar files in the main loop
            }

            let mediaType = MediaType.from(filePath: url.path)
            if mediaType == .unknown { continue }

            var shouldInclude = true
            switch mediaType {
            case .image where !filterImages: shouldInclude = false
            case .video where !filterVideos: shouldInclude = false
            case .audio where !filterAudio: shouldInclude = false
            default: break
            }

            if shouldInclude {
                var file = File(sourcePath: url.path, mediaType: mediaType, status: .waiting)
                
                // Find and attach sidecars
                let baseName = url.deletingPathExtension()
                for sidecarExt in sidecarExtensions {
                    // Perform case-insensitive lookup for sidecar files to support filesystems where
                    // the actual on-disk extension casing may vary (e.g. ".THM", ".XMP").
                    if let matchedURL = allFileURLs.first(where: {
                        $0.deletingPathExtension() == baseName &&
                        $0.pathExtension.lowercased() == sidecarExt
                    }) {
                        file.sidecarPaths.append(matchedURL.path)
                    }
                }
                mainFiles.append(file)
            }
        }
        
        return mainFiles
    }

    private func processFile(
        _ file: File,
        allFiles: [File],
        destinationURL: URL?,
        settings: SettingsStore
    ) async -> File {
        var newFile = file

        // 1. Enrich with metadata and thumbnail
        let url = URL(fileURLWithPath: newFile.sourcePath)
        let (date, size) = await getFileMetadata(url: url, mediaType: newFile.mediaType)
        newFile.date = date
        newFile.size = size
        newFile.thumbnail = await generateThumbnail(for: url)

        // 2. Source-to-source deduplication (same timestamp && size)
        for otherFile in allFiles where otherFile.status != .duplicate_in_source {
            if otherFile.date == newFile.date && otherFile.size == newFile.size {
                newFile.status = .duplicate_in_source
                newFile.duplicateOf = otherFile.id // Link to the master file
                return newFile
            }
        }
        
        // 3. Destination and collision resolution
        newFile = await resolveDestination(
            for: newFile,
            allFiles: allFiles,
            destinationURL: destinationURL,
            settings: settings
        )

        #if DEBUG
        if settings.renameByDate && settings.organizeByDate {
            if let p = newFile.destPath {
                Logger.fileProcessor.debug("final destPath = \(p, privacy: .public)")
            }
        }
        #endif

        return newFile
    }

    /// Returns `true` when the destination file is considered *the same* as the given `sourceFile`.
    ///
    /// The heuristic works in the following order (the first definitive check decides the outcome):
    /// 1. **Size check** – Early-out if the byte sizes differ.
    /// 2. **Filename match** – If the *filenames* (not full paths) are identical, we treat them as the same file even if timestamps differ (typical “overwrite” case).
    /// 3. **Timestamp proximity** – If filenames differ, fall back to a 60-second timestamp window to account for FAT-type filesystems that round seconds.
    /// 4. **SHA-256 checksum** – As a last-resort, calculate a digest of both files and compare. This is expensive but only reached when the previous
    ///    heuristics are inconclusive, and it greatly improves duplicate detection when files are renamed by the importer (e.g. date-based names).
    private func isSameFile(sourceFile: File, destinationURL: URL) async -> Bool {
        guard let sourceSize = sourceFile.size, let sourceDate = sourceFile.date else {
            #if DEBUG
            Logger.fileProcessor.debug("isSameFile – Missing source metadata for \(sourceFile.sourcePath, privacy: .public)")
            #endif
            return false
        }

        let debugPrefix = "[FileProcessorService] DEBUG: isSameFile \(sourceFile.sourcePath) ↔︎ \(destinationURL.path)"

        do {
            let destAttr = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let destSize = destAttr[.size] as? Int64 ?? 0
            let destDate = destAttr[.modificationDate] as? Date ?? .distantPast

            // 1. Size check
            guard sourceSize == destSize else {
                #if DEBUG
                Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – Sizes differ (src: \(sourceSize, privacy: .public), dest: \(destSize, privacy: .public)) → different file")
                #endif
                return false
            }

            let namesMatch = destinationURL.lastPathComponent == URL(fileURLWithPath: sourceFile.sourcePath).lastPathComponent
            if namesMatch {
                #if DEBUG
                Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – Filenames match and sizes match → same file")
                #endif
                return true
            }

            // 3. Timestamp proximity (within 60 seconds)
            let datesClose = abs(sourceDate.timeIntervalSince(destDate)) < 60
            if datesClose {
                #if DEBUG
                Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – Dates within ±60 s (src: \(sourceDate, privacy: .public), dest: \(destDate, privacy: .public)) → same file")
                #endif
                return true
            }

            // 4. SHA-256 checksum fallback
            guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: sourceFile.sourcePath)),
                  let destData = try? Data(contentsOf: destinationURL) else {
                #if DEBUG
                Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – Failed to read file data for checksum → assuming different file")
                #endif
                return false
            }

            let srcDigest = SHA256.hash(data: srcData)
            let destDigest = SHA256.hash(data: destData)

            let isSame = srcDigest == destDigest
#if DEBUG
            Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – Checksum compare → \(isSame ? "same" : "different", privacy: .public) file")
#endif
            return isSame
        } catch {
#if DEBUG
            Logger.fileProcessor.debug("\(debugPrefix, privacy: .public) – File attribute lookup failed (\(error.localizedDescription, privacy: .public)) → assuming different file")
#endif
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
                        #if DEBUG
                        Logger.fileProcessor.debug("Exif dateString = \(dateTimeOriginal, privacy: .public)")
                        #endif
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        dateFormatter.timeZone = TimeZone(identifier: "UTC")
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
        let key = url.path
        if let cached = thumbnailCache[key] {
            return cached
        }

        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
        
        guard let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        
        let img = Image(nsImage: thumbnail.nsImage)
        
        // Store in cache and evict oldest if needed.
        thumbnailCache[key] = img
        thumbnailOrder.append(key)
        if thumbnailOrder.count > thumbnailCacheLimit, let oldestKey = thumbnailOrder.first {
            thumbnailOrder.removeFirst()
            thumbnailCache.removeValue(forKey: oldestKey)
        }
        
        return img
    }

// MARK: - Recalculation Support

/// Recalculates file destination paths and pre-existing status for a new destination.
/// Preserves all expensive metadata (thumbnails, EXIF data, sidecars).
func recalculateFileStatuses(
    for files: [File], 
    destinationURL: URL?, 
    settings: SettingsStore
) async -> [File] {
    // Step 1: Sync path calculation (no file I/O)
    let filesWithPaths = recalculatePathsOnly(for: files, destinationURL: destinationURL, settings: settings)
    
    // Step 2: Async file existence checks
    return await checkPreExistingStatus(for: filesWithPaths)
}

/// Synchronous path recalculation without any file I/O.
/// Perfect for testing - no async, no file system dependencies.
func recalculatePathsOnly(
    for files: [File],
    destinationURL: URL?,
    settings: SettingsStore
) -> [File] {
    guard let destRootURL = destinationURL else {
        // No destination - reset all files to waiting with no destPath
        return files.map { file in
            var newFile = file
            if newFile.status != .duplicate_in_source {
                newFile.destPath = nil
                newFile.status = .waiting
            }
            return newFile
        }
    }
    
    var processedFiles: [File] = []
    
    for file in files {
        // Preserve duplicate_in_source files unchanged
        guard file.status != .duplicate_in_source else {
            processedFiles.append(file)
            continue
        }
        
        // Calculate destination path with collision resolution
        let fileWithPath = calculateDestinationPath(
            for: file,
            allFiles: processedFiles,
            destinationURL: destRootURL,
            settings: settings
        )
        
        processedFiles.append(fileWithPath)
    }
    
    return processedFiles
}

/// Pure path calculation logic - no file I/O, completely synchronous.
private func calculateDestinationPath(
    for file: File,
    allFiles: [File],
    destinationURL: URL,
    settings: SettingsStore
) -> File {
    var newFile = file
    newFile.sidecarPaths = file.sidecarPaths // Explicitly copy sidecarPaths
    
    Logger.fileProcessor.debug("Calculating destination path for \(file.sourceName, privacy: .public) with sidecars: \(file.sidecarPaths, privacy: .public)")
    
    // Reset destination-dependent fields
    newFile.destPath = nil
    newFile.status = .waiting
    
    var suffix = 0
    var isUnique = false
    
    while !isUnique {
        let candidatePath = DestinationPathBuilder.buildFinalDestinationUrl(
            for: newFile,
            in: destinationURL,
            settings: settings,
            suffix: suffix > 0 ? suffix : nil
        )

        // Check against other files in this session only
        let inSessionCollision = allFiles.contains { otherFile in
            guard otherFile.id != newFile.id else { return false }
            return otherFile.destPath == candidatePath.path
        }

        if inSessionCollision {
            suffix += 1
        } else {
            newFile.status = .waiting
            newFile.destPath = candidatePath.path
            isUnique = true
        }
    }
    
    return newFile
}

/// Async file existence checks - only does file I/O.
private func checkPreExistingStatus(for files: [File]) async -> [File] {
    var result: [File] = []
    
    for file in files {
        var updatedFile = file
        
        // Only check files that have destination paths and aren't duplicates
        if let destPath = file.destPath, file.status != .duplicate_in_source {
            if fileManager.fileExists(atPath: destPath) {
                let candidateURL = URL(fileURLWithPath: destPath)
                if await isSameFile(sourceFile: file, destinationURL: candidateURL) {
                    updatedFile.status = .pre_existing
                } else {
                    // Different file exists at destination, keep original status
                    // In production this would trigger collision resolution
                }
            } else {
                // File doesn't exist at destination, should be .waiting
                updatedFile.status = .waiting
            }
        }
        
        result.append(updatedFile)
    }
    
    return result
}

/// Shared destination resolution logic for initial processing.
private func resolveDestination(
    for file: File,
    allFiles: [File],
    destinationURL: URL?,
    settings: SettingsStore
) async -> File {
    guard let destRootURL = destinationURL else {
        return file
    }
    
    // First, calculate path synchronously
    let fileWithPath = calculateDestinationPath(
        for: file,
        allFiles: allFiles,
        destinationURL: destRootURL,
        settings: settings
    )
    
    // Then check file existence asynchronously
        guard fileWithPath.destPath != nil else {
        return fileWithPath
    }
    
    var finalFile = fileWithPath
    
    // Handle collision with existing files on disk
    var suffix = 0
    var isUnique = false
    
    while !isUnique {
        let candidatePath = DestinationPathBuilder.buildFinalDestinationUrl(
            for: file,
            in: destRootURL,
            settings: settings,
            suffix: suffix > 0 ? suffix : nil
        )
        
        if fileManager.fileExists(atPath: candidatePath.path) {
            if await !isSameFile(sourceFile: file, destinationURL: candidatePath) {
                suffix += 1 // Different file exists, try next suffix
            } else {
                // Same file exists, mark as pre-existing
                finalFile.status = .pre_existing
                finalFile.destPath = candidatePath.path
                isUnique = true
            }
        } else {
            // Path is free
            finalFile.destPath = candidatePath.path
            isUnique = true
        }
    }
    
    return finalFile
}
} 