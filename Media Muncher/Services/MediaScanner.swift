import Foundation
import SwiftUI
import AVFoundation
import QuickLookThumbnailing

actor MediaScanner {
    private var enumerationTask: Task<Void, Error>?

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

    func enumerateFiles(at rootURL: URL) -> (results: AsyncThrowingStream<[File], Error>, progress: AsyncStream<Int>) {
        let (progressStream, progressContinuation) = AsyncStream.makeStream(of: Int.self)
        let (resultsStream, resultsContinuation) = AsyncThrowingStream.makeStream(of: [File].self)
        
        self.enumerationTask = Task {
            var filesScanned = 0
            var batch: [File] = []
            let fileManager = FileManager.default
            
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

                    guard fileURL.hasDirectoryPath == false else {
                        if fileURL.lastPathComponent == "THMBNL" {
                            enumerator?.skipDescendants()
                        }
                        continue
                    }
                    
                    let mediaType = MediaType.from(filePath: fileURL.path)
                    if mediaType == .unknown { continue }

                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    let creationDate = resourceValues.creationDate
                    let modificationDate = resourceValues.contentModificationDate
                    let size = Int64(resourceValues.fileSize ?? 0)
                    
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
                    
                    let thumbnail = await generateThumbnail(for: fileURL)
                    
                    let file = File(
                        sourcePath: fileURL.path,
                        mediaType: mediaType,
                        date: mediaDate,
                        size: size,
                        status: FileStatus.waiting,
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