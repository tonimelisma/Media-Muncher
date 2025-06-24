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
        settings: SettingsStore,
        progressHandler: (@Sendable (Int, Int64) async -> Void)? = nil
    ) async throws {
        let didStartAccessing = urlAccessWrapper.startAccessingSecurityScopedResource(for: destinationURL)
        guard didStartAccessing else {
            throw ImportError.destinationNotReachable
        }
        
        defer {
            urlAccessWrapper.stopAccessingSecurityScopedResource(for: destinationURL)
        }
        
        var filesProcessed = 0
        var bytesProcessed: Int64 = 0
        
        for file in files {
            try Task.checkCancellation()
            
            let sourceURL = URL(fileURLWithPath: file.sourcePath)
            
            let destinationPath = DestinationPathBuilder.buildFinalDestinationUrl(
                for: file,
                in: destinationURL,
                settings: settings,
                fileManager: self.fileManager
            )

            let destinationDirectory = destinationPath.deletingLastPathComponent()
            if !self.fileManager.fileExists(atPath: destinationDirectory.path) {
                do {
                    try self.fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    throw ImportError.directoryCreationError(path: destinationDirectory, error: error)
                }
            }
            
            do {
                try self.fileManager.copyItem(at: sourceURL, to: destinationPath)
                filesProcessed += 1
                bytesProcessed += file.size ?? 0
                await progressHandler?(filesProcessed, bytesProcessed)
            } catch {
                throw ImportError.copyFailed(source: sourceURL, destination: destinationPath, error: error)
            }
        }
        
        if settings.settingDeleteOriginals {
            for file in files {
                let sourceURL = URL(fileURLWithPath: file.sourcePath)
                do {
                    try self.fileManager.removeItem(at: sourceURL)

                    // Also try to remove an associated .thm file
                    let thumbnailURL = sourceURL.deletingPathExtension().appendingPathExtension("thm")
                    if self.fileManager.fileExists(atPath: thumbnailURL.path) {
                        try? self.fileManager.removeItem(at: thumbnailURL)
                    }
                    
                    // Also try to remove an associated .THM file (uppercase)
                    let thumbnailURLUpper = sourceURL.deletingPathExtension().appendingPathExtension("THM")
                    if self.fileManager.fileExists(atPath: thumbnailURLUpper.path) {
                        try? self.fileManager.removeItem(at: thumbnailURLUpper)
                    }

                } catch {
                    throw ImportError.deleteFailed(source: sourceURL, error: error)
                }
            }
        }
    }
} 