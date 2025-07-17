//
//  ImportService.swift
//  Media Muncher
//
//  Created by Gemini on 3/8/25.
//

import Foundation

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

actor ImportService {
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

    private let fileManager = FileManager.default
    private let urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol
    private let logManager: Logging
    var nowProvider: () -> Date = { Date() }

    init(
        logManager: Logging = LogManager(),
        urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol = SecurityScopedURLAccessWrapper()
    ) {
        self.logManager = logManager
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

                // Even if we fail to start a security-scoped session (e.g., in unit tests
                // running outside the sandbox), we can still attempt the import as long as
                // the destination path is writable. Only abort if **both** security scope
                // acquisition failed and the location is not writable.
                guard didStartAccessing || fileManager.isWritableFile(atPath: destinationURL.path) else {
                    continuation.finish(throwing: ImportError.destinationNotReachable)
                    return
                }

                defer {
                    if didStartAccessing {
                        urlAccessWrapper.stopAccessingSecurityScopedResource(for: destinationURL)
                    }
                }

                var successfullyImportedIds = Set<String>()

                for var file in files {
                    try Task.checkCancellation()

                    // Handle pre-existing files that should be deleted from source
                    if file.status == .pre_existing && settings.settingDeleteOriginals {
                        do {
                            try deleteSourceFiles(for: file)
                            file.status = .deleted_as_duplicate
                            continuation.yield(file)
                            successfullyImportedIds.insert(file.id)
                        } catch {
                            file.status = .failed
                            file.importError = "Failed to delete original of pre-existing file: \(error.localizedDescription)"
                            continuation.yield(file)
                        }
                        continue // Move to the next file
                    }

                    // Skip files not in .waiting status
                    guard file.status == .waiting else {
                        continue
                    }
                    
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
                        if !fileManager.fileExists(atPath: destDir.path) {
                            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
                        }
                        try fileManager.copyItem(at: sourceURL, to: finalDestinationURL)

                        // Preserve modification & creation timestamps
                        if let attrs = try? fileManager.attributesOfItem(atPath: sourceURL.path),
                           let modDate = attrs[.modificationDate] as? Date,
                           let createDate = attrs[.creationDate] as? Date? {
                            var setAttrs: [FileAttributeKey: Any] = [.modificationDate: modDate]
                            if let create = createDate { setAttrs[.creationDate] = create }
                            try? fileManager.setAttributes(setAttrs, ofItemAtPath: finalDestinationURL.path)
                        }
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
                    var deletionFailed = false
                    if settings.settingDeleteOriginals {
                        do {
                            try deleteSourceFiles(for: file)
                        } catch {
                            // Non-fatal: mark importError and continue so remaining files are processed.
                            deletionFailed = true
                            file.importError = "Failed to delete original (likely read-only volume): \(error.localizedDescription)"
                            // We purposely do NOT throw here.
                        }
                    }

                    // 4. Success (even if deletionFailed)
                    file.status = .imported
                    continuation.yield(file)
                    successfullyImportedIds.insert(file.id)

                    // No global flag returned; caller can inspect file.importError fields later.
                }

                // Final pass to delete source duplicates of successfully imported files
                if settings.settingDeleteOriginals {
                    let duplicateFiles = files.filter { $0.status == .duplicate_in_source }
                    for var duplicate in duplicateFiles {
                        if let masterId = duplicate.duplicateOf, successfullyImportedIds.contains(masterId) {
                            do {
                                try deleteSourceFiles(for: duplicate)
                                duplicate.status = .deleted_as_duplicate
                                continuation.yield(duplicate)
                            } catch {
                                duplicate.status = .failed
                                duplicate.importError = "Failed to delete source duplicate: \(error.localizedDescription)"
                                continuation.yield(duplicate)
                            }
                        }
                    }
                }
                
                continuation.finish()
            }
        }
    }

    // MARK: - Private helpers

    private func deleteSourceFiles(for file: File) throws {
        let allPathsToDelete = [file.sourcePath] + file.sidecarPaths
        
        logManager.debug("Deleting source files", category: "ImportService", metadata: [
            "fileName": file.sourceName,
            "paths": allPathsToDelete.joined(separator: ", ")
        ])
        
        for path in allPathsToDelete {
            let url = URL(fileURLWithPath: path)
            guard fileManager.fileExists(atPath: url.path) else {
                logManager.debug("File not found at path", category: "ImportService", metadata: ["path": path])
                continue
            }
            try fileManager.removeItem(at: url)
            logManager.debug("Deleted file at path", category: "ImportService", metadata: ["path": path])
        }
    }
}
