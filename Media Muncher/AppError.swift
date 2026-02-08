//
//  AppError.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation

/// Domain-specific error types for Media Muncher operations.
///
/// This enum provides typed error handling across all application services with
/// contextual information for debugging and user-facing error messages.
///
/// ## Usage Examples
/// ```swift
/// // Service throwing errors
/// func scanVolume() async throws -> [File] {
///     guard volumeExists else {
///         throw AppError.scanFailed(reason: "Volume no longer available")
///     }
/// }
///
/// // Error handling with user feedback
/// do {
///     try await importFiles()
/// } catch let error as AppError {
///     await MainActor.run {
///         self.errorMessage = error.localizedDescription
///     }
/// }
/// ```
///
/// ## Error Categories
/// - **Scanning**: Volume access and file discovery errors
/// - **Import**: File copying and verification failures  
/// - **Recalculation**: Destination path update errors
/// - **Configuration**: Missing or invalid settings
enum AppError: Error, Identifiable, LocalizedError {
    var id: String { localizedDescription }
    
    /// Volume scanning operation failed due to access or enumeration issues.
    /// - Parameter reason: Detailed explanation of the failure for debugging
    case scanFailed(reason: String)
    
    /// User has not selected a destination folder in Settings.
    /// This error prevents import operations from proceeding.
    case destinationNotSet
    
    /// File import operation failed completely.
    /// - Parameter reason: Detailed explanation of the failure for debugging
    case importFailed(reason: String)
    
    /// Import completed successfully but source file deletion failed.
    /// This typically occurs on read-only volumes or due to permission issues.
    /// - Parameter reason: Detailed explanation of the deletion failure
    case importSucceededWithDeletionErrors(reason: String)
    
    /// Individual file copy operation failed.
    /// - Parameters:
    ///   - source: Source file path that failed to copy
    ///   - reason: Detailed explanation of the copy failure
    case copyFailed(source: String, reason: String)
    
    /// Failed to create required directory structure in destination.
    /// - Parameters:
    ///   - path: Directory path that failed to be created
    ///   - reason: Detailed explanation of the creation failure
    case directoryCreationFailed(path: String, reason: String)
    
    /// Destination path recalculation failed during settings changes.
    /// This can occur when destination becomes unavailable or settings are invalid.
    /// - Parameter reason: Detailed explanation of the recalculation failure
    case recalculationFailed(reason: String)

    /// Volume ejection failed after import completed.
    /// - Parameters:
    ///   - volumeName: Name of the volume that failed to eject
    ///   - reason: Detailed explanation of the ejection failure
    case ejectFailed(volumeName: String, reason: String)
    
    var errorDescription: String? {
        switch self {
        case .scanFailed(let reason):
            return "Scan failed: \(reason)"
        case .destinationNotSet:
            return "Please select a destination folder in Settings before importing."
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        case .importSucceededWithDeletionErrors(let reason):
            return "Import successful, but failed to delete some original files. Please check permissions. Reason: \(reason)"
        case .copyFailed(_, let reason):
            return "Failed to copy file: \(reason)"
        case .directoryCreationFailed(_, let reason):
            return "Failed to create destination directory: \(reason)"
        case .recalculationFailed(let reason):
            return "Failed to recalculate file destinations: \(reason)"
        case .ejectFailed(let volumeName, let reason):
            return "Failed to eject \(volumeName): \(reason)"
        }
    }
    
    /// Helper property to identify recalculation-related errors
    var isRecalculationError: Bool {
        switch self {
        case .recalculationFailed:
            return true
        default:
            return false
        }
    }
} 