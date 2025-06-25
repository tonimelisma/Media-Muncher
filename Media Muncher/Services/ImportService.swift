//
//  ImportService.swift
//  Media Muncher
//
//  Created by Gemini on 3/8/25.
//

import Foundation

// By defining the protocol here, it's available for both the app and tests.
protocol FileManagerProtocol {
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey : Any]?) throws
    func removeItem(at URL: URL) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any]
}

extension FileManager: FileManagerProtocol {}

protocol SecurityScopedURLAccessWrapperProtocol {
    func startAccessingSecurityScopedResource(for url: URL) -> Bool
    func stopAccessingSecurityScopedResource(for url: URL)
}

struct SecurityScopedURLAccessWrapper: SecurityScopedURLAccessWrapperProtocol {
    func startAccessingSecurityScopedResource(for url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessingSecurityScopedResource(for url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

class ImportService {
    enum ImportError: Error, LocalizedError, Equatable {
        case destinationNotReachable
        case copyFailed(source: URL, destination: URL, error: Error)
        case directoryCreationError(path: URL, error: Error)
        case deleteFailed(source: URL, error: Error)
        
        static func == (lhs: ImportService.ImportError, rhs: ImportService.ImportError) -> Bool {
            switch (lhs, rhs) {
            case (.destinationNotReachable, .destinationNotReachable):
                return true
            case let (.copyFailed(source1, dest1, error1), .copyFailed(source2, dest2, error2)):
                return source1.standardized == source2.standardized && dest1.standardized == dest2.standardized && (error1 as NSError) == (error2 as NSError)
            case let (.directoryCreationError(path1, error1), .directoryCreationError(path2, error2)):
                return path1.standardized == path2.standardized && (error1 as NSError) == (error2 as NSError)
            case let (.deleteFailed(source1, error1), .deleteFailed(source2, error2)):
                return source1.standardized == source2.standardized && (error1 as NSError) == (error2 as NSError)
            default:
                return false
            }
        }
    }

    private let fileManager: FileManagerProtocol
    private let urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol
    var nowProvider: () -> Date = { Date() }

    init(
        fileManager: FileManagerProtocol = FileManager.default,
        urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol = SecurityScopedURLAccessWrapper()
    ) {
        self.fileManager = fileManager
        self.urlAccessWrapper = urlAccessWrapper
    }
    
    func importFiles(
        files: [File],
        to destinationURL: URL,
        settings: SettingsStore
    ) -> AsyncThrowingStream<File, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let didStartAccessing = urlAccessWrapper.startAccessingSecurityScopedResource(for: destinationURL)
                guard didStartAccessing else {
                    continuation.finish(throwing: ImportError.destinationNotReachable)
                    return
                }
                
                defer {
                    urlAccessWrapper.stopAccessingSecurityScopedResource(for: destinationURL)
                }

                let filesToImport = files.filter { $0.status == .waiting }

                for var file in filesToImport {
                    try Task.checkCancellation()
                    
                    let sourceURL = URL(fileURLWithPath: file.sourcePath)
                    guard let destinationPath = file.destPath else {
                        // This should have been resolved by FileProcessorService, but as a safeguard:
                        file.status = .failed
                        file.importError = "Destination path could not be determined."
                        continuation.yield(file)
                        continue
                    }
                    let finalDestinationURL = URL(fileURLWithPath: destinationPath)
                    
                    // 1. Copying
                    do {
                        file.status = .copying
                        continuation.yield(file)
                        
                        let destDir = finalDestinationURL.deletingLastPathComponent()
                        if !self.fileManager.fileExists(atPath: destDir.path) {
                            try self.fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
                        }
                        try self.fileManager.copyItem(at: sourceURL, to: finalDestinationURL)
                    } catch {
                        file.status = .failed
                        file.importError = "Copy failed: \(error.localizedDescription)"
                        continuation.yield(file)
                        continue // Move to the next file
                    }
                    
                    // 2. Verification
                    file.status = .verifying
                    continuation.yield(file)
                    
                    do {
                        let destAttrs = try fileManager.attributesOfItem(atPath: finalDestinationURL.path)
                        let sourceAttrs = try fileManager.attributesOfItem(atPath: sourceURL.path)

                        if (destAttrs[.size] as? NSNumber)?.int64Value != (sourceAttrs[.size] as? NSNumber)?.int64Value {
                            file.status = .failed
                            file.importError = "Verification failed: File size mismatch."
                            continuation.yield(file)
                            continue
                        }
                    } catch {
                        file.status = .failed
                        file.importError = "Verification failed: \(error.localizedDescription)"
                        continuation.yield(file)
                        continue
                    }
                    
                    // 3. Deletion
                    if settings.settingDeleteOriginals {
                        do {
                            try self.fileManager.removeItem(at: sourceURL)
                            // Optionally remove common sidecar files, ignoring errors
                            let thmUpper = sourceURL.deletingPathExtension().appendingPathExtension("THM")
                            try? self.fileManager.removeItem(at: thmUpper)
                            let thmLower = sourceURL.deletingPathExtension().appendingPathExtension("thm")
                            try? self.fileManager.removeItem(at: thmLower)
                        } catch {
                            // This is a non-critical error. We can report it but still mark the import as successful.
                            // For now, we'll just log it. A future improvement could be a "warnings" array.
                            print("Non-critical error: Failed to delete source file \(sourceURL.path): \(error.localizedDescription)")
                        }
                    }

                    // 4. Success
                    file.status = .imported
                    continuation.yield(file)
                }
                
                continuation.finish()
            }
        }
    }
} 