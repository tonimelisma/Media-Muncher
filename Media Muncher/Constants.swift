//
//  Constants.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation
import SwiftUI

/// Application-wide constants consolidated for maintainability and performance tuning.
/// All magic numbers and configuration values should be defined here with clear documentation.
enum Constants {
    
    // MARK: - File Processing Constants
    
    /// Maximum number of thumbnails to cache in memory before evicting oldest entries.
    /// This limit prevents memory growth on large volumes while maintaining reasonable performance.
    /// Based on testing, 2000 entries provides good balance between memory usage (~50MB) and hit rate.
    static let thumbnailCacheLimit = 2000
    
    /// Timestamp proximity threshold in seconds for duplicate file detection.
    /// Files with timestamps within this window are considered potentially the same file.
    /// Set to 60 seconds to accommodate FAT filesystem timestamp rounding behavior.
    static let timestampProximityThreshold: TimeInterval = 60
    
    // MARK: - UI Layout Constants
    
    /// Fixed width for grid columns in the media files grid view.
    /// This determines how many thumbnails can fit horizontally in the window.
    /// Value chosen to provide good thumbnail visibility while maximizing grid density.
    static let gridColumnWidth: CGFloat = 120
    
    /// Spacing between grid columns in the media files grid view.
    static let gridColumnSpacing: CGFloat = 10
    
    /// Minimum padding around the grid edges.
    static let gridPadding: CGFloat = 20
    
    // MARK: - File System Constants
    
    /// Log file retention period in seconds (30 days).
    /// Log files older than this threshold are automatically pruned on startup.
    static let logRetentionPeriod: TimeInterval = 30 * 24 * 3600
    
    // MARK: - Performance Constants
    
    /// Minimum bytes processed before checking for task cancellation during long operations.
    /// Balances responsiveness with performance overhead of cancellation checks.
    static let cancellationCheckInterval: Int64 = 1_000_000 // 1MB
    
    // MARK: - Helper Functions
    
    /// Calculates the number of grid columns that fit in the given width.
    /// - Parameter width: Available width for the grid
    /// - Returns: Number of columns that fit with proper spacing
    static func gridColumnsCount(for width: CGFloat) -> Int {
        return Int((width - gridPadding) / (gridColumnWidth + gridColumnSpacing))
    }
}