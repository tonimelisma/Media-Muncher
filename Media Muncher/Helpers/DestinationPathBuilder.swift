//
//  DestinationPathBuilder.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation

/// Builds destination file paths based on user preferences and file metadata.
/// This is the single source of truth for all path generation logic in the application.
///
/// ## Algorithm Overview
/// The path building process consists of three main phases:
/// 1. **Directory Structure**: Creates date-based subdirectories (YYYY/MM/) when enabled
/// 2. **Filename Generation**: Uses capture date (falling back to modification time) or preserves original filename based on settings
/// 3. **Extension Normalization**: Standardizes file extensions (e.g., jpeg → jpg)
///
/// ## Usage Pattern
/// ```swift
/// // Generate relative path for file organization
/// let path = DestinationPathBuilder.relativePath(for: file, organizeByDate: true, renameByDate: true)
/// 
/// // Generate complete destination URL with collision handling
/// let url = DestinationPathBuilder.buildFinalDestinationURL(for: file, in: rootURL, settings: settings)
/// ```
///
/// ## Thread Safety
/// All methods are static and thread-safe. No mutable state is maintained.
struct DestinationPathBuilder {
    /// Normalizes file extensions to their preferred canonical form.
    /// 
    /// This method standardizes various file extensions to reduce duplication and ensure
    /// consistent naming across the destination library. For example, both "jpeg" and "jpe"
    /// are normalized to "jpg".
    /// 
    /// - Parameter ext: The original file extension (case-insensitive)
    /// - Returns: The normalized extension in lowercase
    /// - Performance: O(1) dictionary lookup with static mapping
    static func preferredFileExtension(_ ext: String) -> String {
        let e = ext.lowercased()
        let extensionMapping: [String: String] = [
            "jpeg": "jpg", "jpe": "jpg", "jif": "jpg", "jfif": "jpg", "jfi": "jpg",
            "jp2": "jp2", "j2k": "jp2", "jpf": "jp2", "jpm": "jp2", "jpg2": "jp2",
            "j2c": "jp2", "jpc": "jp2", "jpx": "jp2", "mj2": "jp2", "tif": "tiff",
            "heifs": "heif", "heic": "heif", "heics": "heif", "avci": "heif",
            "avcs": "heif",
            "hif": "heif",
        ]
        return extensionMapping[e] ?? e
    }

    /// Generates the relative path for a file within the destination directory.
    /// 
    /// This method creates the ideal path structure based on user preferences, without handling
    /// filename collisions. The path consists of an optional date-based directory structure
    /// and a filename that may be date-based or preserve the original name.
    /// 
    /// ## Algorithm Details
    /// 1. **Directory Structure**: When `organizeByDate` is true, creates YYYY/MM/ subdirectories
    ///    using the file's capture date (from EXIF metadata) or, if unavailable, the filesystem
    ///    modification time
    /// 2. **Filename Generation**: When `renameByDate` is true, generates YYYYMMDD_HHMMSS format
    ///    using UTC timezone to prevent inconsistencies across different system timezones
    /// 3. **Extension Normalization**: Always applies extension normalization for consistency
    /// 
    /// ## Usage Examples
    /// ```swift
    /// // Photo taken 2025-01-15 14:30:00 with organizeByDate=true, renameByDate=true
    /// // Returns: "2025/01/20250115_143000.jpg"
    ///
    /// // Same photo with organizeByDate=false, renameByDate=false
    /// // Returns: "IMG_0123.jpg" (preserves original filename)
    ///
    /// // Photo missing capture metadata but modification time 2025-01-15 14:30:00
    /// // Returns: "2025/01/20250115_143000.jpg" (falls back to modification date)
    /// ```
    /// 
    /// - Parameters:
    ///   - file: The source file requiring a destination path
    ///   - organizeByDate: Whether to create date-based subdirectories (YYYY/MM/)
    ///   - renameByDate: Whether to rename files using timestamp format
    /// - Returns: Relative path string without collision resolution suffixes
    /// - Note: This method is deterministic and used by both duplicate detection and import operations
    static func relativePath(for file: File, organizeByDate: Bool, renameByDate: Bool) -> String {
        // Use the file's date directly — FileProcessorService.getFileMetadata() already
        // falls back through EXIF → creationDate → modificationDate before this is called.
        let effectiveDate: Date? = file.date

        // Decide directory component
        var directory = ""
        if organizeByDate, let date = effectiveDate {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let comps = cal.dateComponents([.year, .month], from: date)
            if let y = comps.year, let m = comps.month {
                directory = String(format: "%04d/%02d/", y, m)
            }
        }

        // Decide base filename
        let base: String
        if renameByDate, let date = effectiveDate {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let c = cal.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
            let y = c.year ?? 0, mo = c.month ?? 0, d = c.day ?? 0, h = c.hour ?? 0, mi = c.minute ?? 0, s = c.second ?? 0
            base = String(format: "%04d%02d%02d_%02d%02d%02d", y, mo, d, h, mi, s)
        } else {
            base = file.filenameWithoutExtension
        }

        let ext = preferredFileExtension(file.fileExtension)
        return directory + base + "." + ext
    }

    /// Builds the complete destination URL for a file, including collision resolution.
    /// 
    /// This method combines the relative path generation with the root destination URL
    /// and applies numerical suffixes when needed to resolve filename collisions.
    /// 
    /// ## Collision Resolution Algorithm
    /// When a collision is detected (suffix > 0), the method appends a numerical suffix
    /// to the base filename before the extension:
    /// - Original: "photo.jpg" → Collision: "photo_1.jpg", "photo_2.jpg", etc.
    /// - Preserves file extension and directory structure
    /// - Suffix counter increments until a unique filename is found
    /// 
    /// ## Error Handling
    /// This method never fails - it will always return a valid URL. If path components
    /// are invalid, URL construction handles gracefully by percent-encoding.
    /// 
    /// - Parameters:
    ///   - file: The source file requiring a destination URL
    ///   - rootURL: The root destination directory URL
    ///   - settings: User settings containing path preferences
    ///   - suffix: Optional numerical suffix for collision resolution (nil = no suffix)
    /// - Returns: Complete destination URL ready for file operations
    /// - Complexity: O(1) for path generation, collision detection handled by caller
    static func buildFinalDestinationURL(
        for file: File,
        in rootURL: URL,
        settings: SettingsStore,
        suffix: Int? = nil
    ) -> URL {
        let relativePath = Self.relativePath(for: file, organizeByDate: settings.organizeByDate, renameByDate: settings.renameByDate)
        
        var idealURL = rootURL.appendingPathComponent(relativePath)
        
        if let suffix = suffix {
            let baseFilename = idealURL.deletingPathExtension().lastPathComponent
            let fileExtension = idealURL.pathExtension
            let newFilename = "\(baseFilename)_\(suffix).\(fileExtension)"
            idealURL = idealURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        }
        
        return idealURL
    }
} 