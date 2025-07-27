import Foundation
import SwiftUI
import AVFoundation
import CryptoKit // For SHA-256 checksum fallback when date/name heuristics fail

/// Actor responsible for file discovery, metadata extraction, and destination path calculation.
/// 
/// ## Async Pattern: Actor-Based Concurrency
/// This service is implemented as an actor to provide thread-safe access to file system operations.
/// Thumbnail generation is now delegated to FileStore to centralize UI-related state management.
/// 
/// ## Usage Pattern:
/// ```swift
/// // From MainActor (AppState)
/// let files = await fileProcessorService.processFiles(from: volume, destinationURL: dest, settings: settings, fileStore: fileStore)
/// 
/// // For recalculation (sync path calculation + async file checks)
/// let recalculatedFiles = await fileProcessorService.recalculateFileStatuses(for: files, destinationURL: newDest, settings: settings)
/// ```
/// 
/// ## Responsibilities:
/// - File discovery and enumeration on volumes
/// - EXIF metadata extraction (delegates thumbnail generation to FileStore)
/// - Destination path calculation and collision resolution
/// - Pre-existing file detection using multiple heuristics
/// - Sidecar file (THM, XMP, LRC) association
actor FileProcessorService {

    private let fileManager = FileManager.default
    private let logManager: Logging
    private let thumbnailCache: ThumbnailCache

    init(logManager: Logging = LogManager(), thumbnailCache: ThumbnailCache = ThumbnailCache()) {
        self.logManager = logManager
        self.thumbnailCache = thumbnailCache
    }

    func processFiles(
        from sourceURL: URL,
        destinationURL: URL?,
        settings: SettingsStore
    ) async -> [File] {
        await logManager.debug("processFiles called", category: "FileProcessor")
        await logManager.debug("Processing files", category: "FileProcessor", metadata: [
            "sourceURL": sourceURL.path,
            "destinationURL": destinationURL?.path ?? "nil",
            "filterImages": "\(settings.filterImages)",
            "filterVideos": "\(settings.filterVideos)",
            "filterAudio": "\(settings.filterAudio)",
            "filterRaw": "\(settings.filterRaw)"
        ])
        
        let discoveredFilesUnsorted = fastEnumerate(
            at: sourceURL,
            filterImages: settings.filterImages,
            filterVideos: settings.filterVideos,
            filterAudio: settings.filterAudio,
            filterRaw: settings.filterRaw
        )
        
        await logManager.debug("fastEnumerate found files", category: "FileProcessor", metadata: ["count": "\(discoveredFilesUnsorted.count)"])

        // Ensure deterministic processing order so collision suffixes are repeatable across runs/tests
        let discoveredFiles = discoveredFilesUnsorted.sorted { $0.sourcePath < $1.sourcePath }

        var processedFiles: [File] = []
        for file in discoveredFiles {
            await logManager.debug("Processing file", category: "FileProcessor", metadata: ["sourcePath": file.sourcePath])
            let processedFile = await processFile(
                file,
                allFiles: processedFiles,
                destinationURL: destinationURL,
                settings: settings
            )
            processedFiles.append(processedFile)
        }
        
        await logManager.debug("processFiles completed", category: "FileProcessor", metadata: ["count": "\(processedFiles.count)"])
        return processedFiles
    }
    
    /// Streaming version of processFiles that yields batches of files as they're processed
    /// This enables progressive UI updates during file scanning to prevent UI jank
    func processFilesStream(
        from sourceURL: URL,
        destinationURL: URL?,
        settings: SettingsStore,
        batchSize: Int = 50
    ) -> AsyncStream<[File]> {
        return AsyncStream { continuation in
            Task {
                await logManager.debug("processFilesStream called", category: "FileProcessor", metadata: [
                    "sourceURL": sourceURL.path,
                    "destinationURL": destinationURL?.path ?? "nil",
                    "batchSize": "\(batchSize)"
                ])
                
                let discoveredFilesUnsorted = fastEnumerate(
                    at: sourceURL,
                    filterImages: settings.filterImages,
                    filterVideos: settings.filterVideos,
                    filterAudio: settings.filterAudio,
                    filterRaw: settings.filterRaw
                )
                
                await logManager.debug("fastEnumerate found files for stream", category: "FileProcessor", metadata: ["count": "\(discoveredFilesUnsorted.count)"])
                
                // Ensure deterministic processing order
                let discoveredFiles = discoveredFilesUnsorted.sorted { $0.sourcePath < $1.sourcePath }
                
                var processedFiles: [File] = []
                var batch: [File] = []
                
                for file in discoveredFiles {
                    do {
                        try Task.checkCancellation()
                        
                        await logManager.debug("Processing file in stream", category: "FileProcessor", metadata: ["sourcePath": file.sourcePath])
                        let processedFile = await processFile(
                            file,
                            allFiles: processedFiles,
                            destinationURL: destinationURL,
                            settings: settings
                        )
                        
                        processedFiles.append(processedFile)
                        batch.append(processedFile)
                        
                        // Yield batch when it reaches the specified size
                        if batch.count >= batchSize {
                            continuation.yield(batch)
                            batch.removeAll()
                        }
                    } catch {
                        // Task was cancelled, clean up and finish
                        await logManager.debug("processFilesStream cancelled", category: "FileProcessor")
                        continuation.finish()
                        return
                    }
                }
                
                // Yield any remaining files in the final batch
                if !batch.isEmpty {
                    continuation.yield(batch)
                }
                
                await logManager.debug("processFilesStream completed", category: "FileProcessor", metadata: ["totalCount": "\(processedFiles.count)"])
                continuation.finish()
            }
        }
    }

    private func fastEnumerate(
        at rootURL: URL,
        filterImages: Bool,
        filterVideos: Bool,
        filterAudio: Bool,
        filterRaw: Bool
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
            case .raw where !filterRaw: shouldInclude = false
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
        newFile.thumbnailData = await thumbnailCache.thumbnailData(for: url)

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
                await logManager.debug("final destPath", category: "FileProcessor", metadata: ["path": p])
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
    /// 3. **Timestamp proximity** – If filenames differ, fall back to a configurable timestamp window to account for FAT-type filesystems that round seconds.
    /// 4. **SHA-256 checksum** – As a last-resort, calculate a digest of both files and compare. This is expensive but only reached when the previous
    ///    heuristics are inconclusive, and it greatly improves duplicate detection when files are renamed by the importer (e.g. date-based names).
    private func isSameFile(sourceFile: File, destinationURL: URL) async -> Bool {
        guard let sourceSize = sourceFile.size, let sourceDate = sourceFile.date else {
            #if DEBUG
            await logManager.debug("isSameFile – Missing source metadata", category: "FileProcessor", metadata: ["sourcePath": sourceFile.sourcePath])
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
                            await logManager.debug("Sizes differ → different file", category: "FileProcessor", metadata: [
                "debugPrefix": debugPrefix,
                "sourceSize": "\(sourceSize)",
                "destSize": "\(destSize)"
            ])
                #endif
                return false
            }

            let namesMatch = destinationURL.lastPathComponent == URL(fileURLWithPath: sourceFile.sourcePath).lastPathComponent
            if namesMatch {
                #if DEBUG
                await logManager.debug("Filenames match and sizes match → same file", category: "FileProcessor", metadata: ["debugPrefix": debugPrefix])
                #endif
                return true
            }

            // 3. Timestamp proximity (within configured threshold)
            let datesClose = abs(sourceDate.timeIntervalSince(destDate)) < Constants.timestampProximityThreshold
            if datesClose {
                #if DEBUG
                await logManager.debug("Dates within threshold → same file", category: "FileProcessor", metadata: [
                    "debugPrefix": debugPrefix,
                    "sourceDate": "\(sourceDate)",
                    "destDate": "\(destDate)"
                ])
                #endif
                return true
            }

            // 4. SHA-256 checksum fallback
            guard let srcData = try? Data(contentsOf: URL(fileURLWithPath: sourceFile.sourcePath)),
                  let destData = try? Data(contentsOf: destinationURL) else {
                #if DEBUG
                await logManager.debug("Failed to read file data for checksum → assuming different file", category: "FileProcessor", metadata: ["debugPrefix": debugPrefix])
                #endif
                return false
            }

            let srcDigest = SHA256.hash(data: srcData)
            let destDigest = SHA256.hash(data: destData)

            let isSame = srcDigest == destDigest
#if DEBUG
            await logManager.debug("Checksum compare", category: "FileProcessor", metadata: [
                "debugPrefix": debugPrefix,
                "result": isSame ? "same" : "different"
            ])
#endif
            return isSame
        } catch {
#if DEBUG
                    await logManager.debug("File attribute lookup failed → assuming different file", category: "FileProcessor", metadata: [
            "debugPrefix": debugPrefix,
            "error": error.localizedDescription
        ])
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
                        await logManager.debug("Exif dateString", category: "FileProcessor", metadata: ["dateTimeOriginal": dateTimeOriginal])
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

    // Thumbnail generation handled by ThumbnailCache injected via init.

// MARK: - Recalculation Support

/// Recalculates file destination paths with unified collision resolution.
/// Uses the same DRY collision resolution logic as initial processing.
/// Preserves all expensive metadata (thumbnails, EXIF data, sidecars).
func recalculateFileStatuses(
    for files: [File], 
    destinationURL: URL?, 
    settings: SettingsStore
) async -> [File] {
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
        
        // Use shared collision resolution logic - DRY!
        let fileWithPath = await calculateDestinationPathWithCollisionResolution(
            for: file,
            allFiles: processedFiles,
            destinationURL: destRootURL,
            settings: settings
        )
        
        processedFiles.append(fileWithPath)
    }
    
    return processedFiles
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
/// Only checks session collisions, used by recalculatePathsOnly for testing.
private func calculateDestinationPath(
    for file: File,
    allFiles: [File],
    destinationURL: URL,
    settings: SettingsStore
) -> File {
    var newFile = file
    newFile.sidecarPaths = file.sidecarPaths // Explicitly copy sidecarPaths
    
    Task {
        await logManager.debug("Calculating destination path", category: "FileProcessor", metadata: [
            "fileName": file.sourceName,
            "sidecars": file.sidecarPaths.joined(separator: ", ")
        ])
    }
    
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

// REMOVED: checkPreExistingStatus - now handled by unified resolveDestination

/// Core unified collision resolution logic - DRY implementation used by all path resolution.
/// Checks both session files and disk files in one pass to prevent suffix counter reset bug.
private func calculateDestinationPathWithCollisionResolution(
    for file: File,
    allFiles: [File],
    destinationURL: URL,
    settings: SettingsStore
) async -> File {
    var newFile = file
    newFile.sidecarPaths = file.sidecarPaths // Explicitly copy sidecarPaths
    
    await logManager.debug("Calculating destination path with unified collision resolution", category: "FileProcessor", metadata: [
        "fileName": file.sourceName,
        "sidecars": file.sidecarPaths.joined(separator: ", ")
    ])
    
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
        
        // Check both session files AND disk in one pass
        let sessionCollision = allFiles.contains { otherFile in
            guard otherFile.id != newFile.id else { return false }
            return otherFile.destPath == candidatePath.path
        }
        let diskCollision = fileManager.fileExists(atPath: candidatePath.path)
        
        if sessionCollision {
            // Session collision - increment suffix and try again
            suffix += 1
        } else if diskCollision {
            // Disk collision - check if it's the same file
            if await isSameFile(sourceFile: file, destinationURL: candidatePath) {
                newFile.status = .pre_existing
                newFile.destPath = candidatePath.path
                isUnique = true
            } else {
                // Different file exists, increment suffix and try again
                suffix += 1
            }
        } else {
            // No collision - path is free
            newFile.destPath = candidatePath.path
            newFile.status = .waiting
            isUnique = true
        }
    }
    
    return newFile
}

/// Wrapper for initial file processing - delegates to shared collision resolution logic.
private func resolveDestination(
    for file: File,
    allFiles: [File],
    destinationURL: URL?,
    settings: SettingsStore
) async -> File {
    guard let destRootURL = destinationURL else {
        return file
    }
    
    return await calculateDestinationPathWithCollisionResolution(
        for: file,
        allFiles: allFiles,
        destinationURL: destRootURL,
        settings: settings
    )
}
} 