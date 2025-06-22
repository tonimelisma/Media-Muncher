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
    
    private let fileManager: FileManagerProtocol
    private let urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol

    init(
        fileManager: FileManagerProtocol = FileManager.default,
        urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol = SecurityScopedURLAccessWrapper()
    ) {
        self.fileManager = fileManager
        self.urlAccessWrapper = urlAccessWrapper
    }

    enum ImportError: Error, LocalizedError, Equatable {
        case destinationNotReachable
        case copyFailed(source: URL, destination: URL, error: Error)
        
        static func == (lhs: ImportService.ImportError, rhs: ImportService.ImportError) -> Bool {
            switch (lhs, rhs) {
            case (.destinationNotReachable, .destinationNotReachable):
                return true
            case let (.copyFailed(source1, destination1, error1), .copyFailed(source2, destination2, error2)):
                return source1 == source2 &&
                       destination1 == destination2 &&
                       error1.localizedDescription == error2.localizedDescription
            default:
                return false
            }
        }

        var errorDescription: String? {
            switch self {
            case .destinationNotReachable:
                return "The destination folder is not reachable. Please select it again in Settings."
            case .copyFailed(let source, _, let error):
                return "Failed to copy '\(source.lastPathComponent)': \(error.localizedDescription)"
            }
        }
    }
    
    func importFiles(files: [File], to destinationURL: URL) async throws {
        let didStartAccessing = urlAccessWrapper.startAccessingSecurityScopedResource(for: destinationURL)
        guard didStartAccessing else {
            throw ImportError.destinationNotReachable
        }
        
        defer {
            urlAccessWrapper.stopAccessingSecurityScopedResource(for: destinationURL)
        }
        
        for file in files {
            let sourceURL = URL(fileURLWithPath: file.sourcePath)
            let destinationPath = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
            
            do {
                try self.fileManager.copyItem(at: sourceURL, to: destinationPath)
            } catch {
                throw ImportError.copyFailed(source: sourceURL, destination: destinationPath, error: error)
            }
        }
    }
} 