//
//  FileStore.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation
import SwiftUI

/// Centralized state manager for file data and related UI operations.
/// This class encapsulates all logic for managing the files array and provides
/// a clean interface for file-related state management.
///
/// ## Async Pattern: MainActor + Combine Publishers
/// This service runs on MainActor for seamless SwiftUI integration and uses
/// @Published properties for reactive UI updates. It delegates file I/O
/// operations to appropriate actors while maintaining UI state consistency.
///
/// ## Usage Pattern:
/// ```swift
/// // From SwiftUI Views
/// @EnvironmentObject var fileStore: FileStore
/// 
/// // Access files directly
/// ForEach(fileStore.files) { file in
///     MediaFileCellView(file: file)
/// }
/// 
/// // Update files from background actors
/// await fileStore.setFiles(newFiles)
/// ```
///
/// ## Responsibilities:
/// - Manage files array and derived state
/// - Provide computed properties for UI bindings
/// - Handle file updates from background services
/// - Maintain thumbnail cache for UI performance
/// - Coordinate with FileProcessorService for file operations
@MainActor
final class FileStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The main files array that drives the UI
    @Published private(set) var files: [File] = []
    
    // MARK: - Private Properties
    
    private let logManager: Logging
    
    // Thumbnail cache logic has moved to `ThumbnailCache` actor.
    
    // MARK: - Initialization
    
    init(logManager: Logging) {
        self.logManager = logManager
        // We are on the MainActor. We can't await here, but we can fire-and-forget
        // a detached task to ensure this log is captured without blocking.
        Task.detached {
            let message = "FileStore.init() called - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)"
            await logManager.debug(message, category: "FileStore")
            await logManager.debug("FileStore initialized", category: "FileStore")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Total number of files
    var fileCount: Int {
        files.count
    }
    
    /// Files that need to be imported
    var filesToImport: [File] {
        files.filter { file in
            file.status == .waiting || file.status == .failed
        }
    }
    
    /// Files that have been successfully imported
    var importedFiles: [File] {
        files.filter { file in
            file.status == .imported || file.status == .imported_with_deletion_error
        }
    }
    
    /// Files that already exist at destination
    var preExistingFiles: [File] {
        files.filter { file in
            file.status == .pre_existing
        }
    }
    
    /// Files that are duplicates within the source
    var duplicateFiles: [File] {
        files.filter { file in
            file.status == .duplicate_in_source
        }
    }
    
    // MARK: - File Management
    
    /// Updates the files array from a background service
    func setFiles(_ newFiles: [File]) {
        Task {
            await logManager.debug("Setting files", category: "FileStore", metadata: ["count": "\(newFiles.count)"])
        }
        files = newFiles
    }
    
    /// Appends files to the existing files array (used for batched UI updates)
    func appendFiles(_ newFiles: [File]) {
        Task {
            await logManager.debug("Appending files", category: "FileStore", metadata: ["count": "\(newFiles.count)", "totalAfter": "\(files.count + newFiles.count)"])
        }
        files.append(contentsOf: newFiles)
    }
    
    /// Updates a single file in the array
    func updateFile(_ updatedFile: File) {
        if let index = files.firstIndex(where: { $0.id == updatedFile.id }) {
            files[index] = updatedFile
            Task {
                await logManager.debug("Updated file", category: "FileStore", metadata: [
                    "id": updatedFile.id,
                    "status": updatedFile.status.rawValue
                ])
            }
        } else {
            Task {
                await logManager.error("Attempted to update non-existent file", category: "FileStore", metadata: ["id": updatedFile.id])
            }
        }
    }
    
    /// Updates multiple files in the array
    func updateFiles(_ updatedFiles: [File]) {
        for file in updatedFiles {
            updateFile(file)
        }
    }
    
    /// Clears all files from the store
    func clearFiles() {
        Task {
            await logManager.debug("Clearing all files", category: "FileStore")
        }
        files.removeAll()
    }
    
    // MARK: - Thumbnail Management

    // Thumbnail management removed.  Thumbnails are now handled by `ThumbnailCache` actor off the main thread.

    // MARK: - File Queries
    
    /// Finds a file by its ID
    /// - Parameter id: The unique identifier of the file
    /// - Returns: The file if found, nil otherwise
    func file(withId id: String) -> File? {
        return files.first { $0.id == id }
    }
} 