import Foundation
import SwiftUI
import AVFoundation
import QuickLookThumbnailing

actor FileProcessorService {

    // Thumbnail Cache
    private var thumbnailCache: [String: Image] = [:] // key = file path
    private var thumbnailOrder: [String] = []
    private let thumbnailCacheLimit = 2000
    
    private let fileManager = FileManager.default

    init() {
        print("[FileProcessorService] DEBUG: Initialized")
    }

    func processFiles(
        from sourceURL: URL,
        destinationURL: URL?,
        settings: SettingsStore
    ) async -> [File] {
        print("[FileProcessorService] DEBUG: processFiles called")
        print("[FileProcessorService] DEBUG: sourceURL: \(sourceURL.path)")
        print("[FileProcessorService] DEBUG: destinationURL: \(destinationURL?.path ?? "nil")")
        print("[FileProcessorService] DEBUG: filterImages: \(settings.filterImages)")
        print("[FileProcessorService] DEBUG: filterVideos: \(settings.filterVideos)")
        print("[FileProcessorService] DEBUG: filterAudio: \(settings.filterAudio)")
        
        let discoveredFilesUnsorted = fastEnumerate(
            at: sourceURL,
            filterImages: settings.filterImages,
            filterVideos: settings.filterVideos,
            filterAudio: settings.filterAudio
        )
        
        print("[FileProcessorService] DEBUG: fastEnumerate found \(discoveredFilesUnsorted.count) files")

        // Ensure deterministic processing order so collision suffixes are repeatable across runs/tests
        let discoveredFiles = discoveredFilesUnsorted.sorted { $0.sourcePath < $1.sourcePath }

        var processedFiles: [File] = []
        for file in discoveredFiles {
            print("[FileProcessorService] DEBUG: Processing file: \(file.sourcePath)")
            let processedFile = await processFile(
                file,
                allFiles: processedFiles,
                destinationURL: destinationURL,
                settings: settings
            )
            processedFiles.append(processedFile)
        }
        
        print("[FileProcessorService] DEBUG: processFiles completed with \(processedFiles.count) files")
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
        let allURLSet = Set(allFileURLs)

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
                    let sidecarURL = baseName.appendingPathExtension(sidecarExt)
                    if allURLSet.contains(sidecarURL) {
                        file.sidecarPaths.append(sidecarURL.path)
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

        #if DEBUG
        if settings.renameByDate && settings.organizeByDate {
            if let p = newFile.destPath {
                print("[FileProcessorService] DEBUG: final destPath = \(p)")
            }
        }
        #endif

        return newFile
    }

    private func isSameFile(sourceFile: File, destinationURL: URL) async -> Bool {
        guard let sourceSize = sourceFile.size, let sourceDate = sourceFile.date else { return false }

        do {
            let destAttr = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let destSize = destAttr[.size] as? Int64 ?? 0
            let destDate = destAttr[.modificationDate] as? Date ?? .distantPast
            
            let namesMatch = destinationURL.lastPathComponent == URL(fileURLWithPath: sourceFile.sourcePath).lastPathComponent
            if sourceSize != destSize { return false }

            // If filenames match, treat as same regardless of date difference. Otherwise fallback to date proximity (60s).
            if namesMatch { return true }

            let datesClose = abs(sourceDate.timeIntervalSince(destDate)) < 60
            return datesClose
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
                        #if DEBUG
                        print("[FileProcessorService] DEBUG: Exif dateString = \(dateTimeOriginal)")
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
} 