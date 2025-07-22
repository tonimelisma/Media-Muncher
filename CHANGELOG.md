# Changelog

## [2025-07-22] - Data Race Fix

### Fixed
- **CRITICAL**: Eliminated data race in File model by replacing unsafe `nonisolated(unsafe) var thumbnail: Image?` with thread-safe `thumbnailData: Data?` and `thumbnailSize: CGSize?` properties
- Updated ThumbnailCache to work with PNG data instead of SwiftUI Image objects for thread safety
- Modified MediaFileCellView to convert thumbnail data to Image on MainActor for safe UI display
- Updated FileProcessorService to generate thumbnail data instead of Image objects

### Technical Details
- File model is now properly Sendable without unsafe concurrency annotations
- ThumbnailCache actor stores PNG data with LRU eviction, maintaining same performance characteristics
- UI layer handles Data→Image conversion on MainActor eliminating cross-thread Image access
- Backwards compatibility maintained with legacy `thumbnail(for:)` method in ThumbnailCache

### Files Changed
- FileModel.swift: Replaced thumbnail property with thumbnailData/thumbnailSize
- ThumbnailCache.swift: Updated to work with Data instead of Image
- MediaFileCellView.swift: Added safe thumbnail loading from data
- FileProcessorService.swift: Updated to use new thumbnailData API
- ContentView.swift: Fixed Preview initialization for async AppContainer
- Test files: Updated File constructors to use new property names

### Risks Addressed
- Eliminated potential crashes from concurrent SwiftUI Image access
- Removed Swift Concurrency safety violations
- Maintained existing thumbnail caching performance and UI behavior