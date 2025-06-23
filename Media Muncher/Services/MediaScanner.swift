import Foundation
import SwiftUI
import AVFoundation
import QuickLookThumbnailing

actor MediaScanner {
    private var enumerationTask: Task<Void, Error>?
    private static let thumbnailFolderNames: Set<String> = ["thmbnl", ".thumbnails", "misc"]

    private func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 256, height: 256)) async -> Image? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: NSScreen.main?.backingScaleFactor ?? 1.0, representationTypes: .all)
        
        guard let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        
        return Image(nsImage: thumbnail.nsImage)
    }

    func cancelEnumeration() {
        enumerationTask?.cancel()
    }

    func enumerateFiles(
        at rootURL: URL,
        destinationURL: URL?,
        filterImages: Bool,
        filterVideos: Bool,
        filterAudio: Bool
    ) -> (results: AsyncThrowingStream<[File], Error>, progress: AsyncStream<Int>) {
        let (progressStream, progressContinuation) = AsyncStream.makeStream(of: Int.self)
        let (resultsStream, resultsContinuation) = AsyncThrowingStream.makeStream(of: [File].self)
        
        self.enumerationTask = Task {
            var filesScanned = 0
            var batch: [File] = []
            let fileManager = FileManager.default
            var destinationFiles: [String: (size: Int64, date: Date)] = [:]
            
            if let destinationURL = destinationURL {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    let destResourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey, .fileSizeKey]
                    if let enumerator = fileManager.enumerator(at: destinationURL, includingPropertiesForKeys: Array(destResourceKeys)) {
                        while let fileURL = enumerator.nextObject() as? URL {
                            guard !fileURL.hasDirectoryPath else { continue }
                            do {
                                let resourceValues = try fileURL.resourceValues(forKeys: destResourceKeys)
                                let size = Int64(resourceValues.fileSize ?? 0)
                                let date = resourceValues.contentModificationDate ?? resourceValues.creationDate ?? Date.distantPast
                                destinationFiles[fileURL.lastPathComponent] = (size, date)
                            } catch {
                                // Log error or handle, for now, we'll just skip this file
                            }
                        }
                    }
                }
            }

            do {
                defer {
                    resultsContinuation.finish()
                    progressContinuation.finish()
                }

                let resourceKeys: Set<URLResourceKey> = [
                    .creationDateKey, .contentModificationDateKey, .fileSizeKey,
                ]
                let enumerator = fileManager.enumerator(
                    at: rootURL, includingPropertiesForKeys: Array(resourceKeys))
                
                while let fileURL = enumerator?.nextObject() as? URL {
                    try Task.checkCancellation()

                    if fileURL.hasDirectoryPath {
                        if MediaScanner.thumbnailFolderNames.contains(fileURL.lastPathComponent.lowercased()) {
                            enumerator?.skipDescendants()
                        }
                        continue
                    }
                    
                    let mediaType = MediaType.from(filePath: fileURL.path)
                    if mediaType == .unknown { continue }

                    // Apply filters
                    switch mediaType {
                    case .image where !filterImages:
                        continue
                    case .video where !filterVideos:
                        continue
                    case .audio where !filterAudio:
                        continue
                    default:
                        break
                    }

                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    let creationDate = resourceValues.creationDate
                    let modificationDate = resourceValues.contentModificationDate
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let sourceName = fileURL.lastPathComponent
                    
                    var mediaDate: Date?
                    
                    if mediaType == .video {
                        let asset = AVURLAsset(url: fileURL)
                        if let creationDate = try? await asset.load(.creationDate),
                           let dateValue = try? await creationDate.load(.dateValue) {
                            mediaDate = dateValue
                        }
                    } else if mediaType == .image {
                        if let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
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
                        mediaDate = creationDate ?? modificationDate
                    }
                    
                    var status: FileStatus = .waiting
                    if let destFile = destinationFiles[sourceName], let mediaDate = mediaDate {
                        if destFile.size == size && abs(destFile.date.timeIntervalSince(mediaDate)) < 2 { // allow 1s variance
                            status = .pre_existing
                        }
                    }
                    
                    let thumbnail = await generateThumbnail(for: fileURL)
                    
                    let file = File(
                        sourcePath: fileURL.path,
                        mediaType: mediaType,
                        date: mediaDate,
                        size: size,
                        status: status,
                        thumbnail: thumbnail
                    )
                    
                    batch.append(file)
                    filesScanned += 1
                    progressContinuation.yield(filesScanned)
                    
                    if batch.count >= 50 {
                        resultsContinuation.yield(batch)
                        batch.removeAll()
                    }
                }
                
                if !batch.isEmpty {
                    resultsContinuation.yield(batch)
                }
                
            } catch {
                if !(error is CancellationError) {
                    resultsContinuation.finish(throwing: error)
                    progressContinuation.finish()
                } else {
                    resultsContinuation.finish()
                    progressContinuation.finish()
                }
            }
        }
        
        return (resultsStream, progressStream)
    }
} 