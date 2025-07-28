# Changelog

## [2025-07-27] - Code Cleanup

### Fixed
- **Duplicate source files**: Removed obsolete source files from the project, which were left over from a previous refactoring. This improves maintainability and reduces confusion.

### Changed
- **Project structure**: The project now has a cleaner and more organized file structure.

### Technical Details
- **Files Removed**:
  - `Media Muncher/Models/FileModel.swift`
  - `Media Muncher/Models/VolumeModel.swift`
  - `Media Muncher/Views/ContentView.swift`
  - `Media Muncher/Views/MediaGridView.swift`
  - `Media Muncher/Views/MediaFileCellView.swift`
  - `Media Muncher/Views/VolumeListView.swift`

## [2025-01-26] - SettingsStore Race Condition Fix

### Fixed
- **Critical race condition in SettingsStore initialization** - Eliminated async operations from constructor causing intermittent test failures
- **Test isolation issues** - Fixed `testSettingsStoreBindingExistsCorrectly()` that failed in full test suite but passed individually
- **Synchronous initialization pattern** - SettingsStore now provides immediate deterministic destination URL availability

### Changed
- **SettingsStore constructor** - Now fully synchronous with `computeDefaultDestination()` static method
- **Logging pattern** - Moved initialization logging to fire-and-forget Tasks preserving async logging elsewhere
- **Default destination logic** - Centralized in pure function for deterministic file system checks

### Added
- **Synchronous initialization tests** - Added `testSynchronousInitialization()` and `testImmediateDestinationAvailability()` 
- **Race condition regression tests** - Enhanced existing test to verify immediate destination availability

### Technical Details
- **Files Modified**:
  - `Media Muncher/Services/SettingsStore.swift` - Replaced async `setDefaults()` with sync `computeDefaultDestination()`
  - `Media MuncherTests/AppStateRecalculationUnitTests.swift` - Simplified test to verify immediate availability
  - `Media MuncherTests/SettingsStoreTests.swift` - Added comprehensive synchronous initialization tests

### Architecture Impact
- **Eliminated race conditions**: Constructor now completes all initialization synchronously
- **Maintained API compatibility**: No breaking changes to public interface
- **Improved production reliability**: Consistent initialization behavior under all load conditions
- **Enhanced test reliability**: Fixed flaky test that revealed deeper architectural issue

### Validation Results
- **Individual test runs**: ✅ 10/10 passes
- **Full test suite**: ✅ All AppStateRecalculationUnitTests pass consistently
- **Performance**: Initialization time <100ms, no functional impact

## [2025-01-26] - Test Reliability Improvements

### Fixed
- **Eliminated all Task.sleep() calls from test suite** - Replaced time-dependent testing patterns with deterministic dependency injection
- **ImportProgressTests performance** - Time calculation tests now run in <1ms instead of 1+ seconds using fixed date injection
- **TestDataFactory polling** - Replaced sleep-based polling with cooperative multitasking using Task.yield()
- **Test suite consistency** - Removed unnecessary SimpleAsyncTest.swift file that provided no value

### Added
- **ImportProgress testing methods** - Added `startForTesting()`, `elapsedSecondsForTesting()`, and `remainingSecondsForTesting()` for deterministic time calculations
- **Test validation** - Added `testTestingMethodsProvideConsistentResults()` to ensure test methods behave consistently with production code

### Technical Details
- **Files Modified**: 
  - `Media Muncher/ImportProgress.swift` - Added test-specific methods with explicit time parameters
  - `Media MuncherTests/ImportProgressTests.swift` - Replaced sleep-based timing test with fixed date calculations  
  - `Media MuncherTests/TestSupport/TestDataFactory.swift` - Replaced Task.sleep() with Task.yield() in polling
  - `Media MuncherTests/SimpleAsyncTest.swift` - Deleted entire file (unnecessary infrastructure test)

### Performance Impact
- **Test execution speed**: ImportProgressTests now run in ~1ms vs 1000ms+ previously
- **Test reliability**: 100% deterministic behavior, no timing dependencies
- **Build performance**: Faster test suite execution with no functional changes to production code

### Architecture Notes
- Testing methods in `ImportProgress` are isolated to a dedicated "Testing Support" section
- All test infrastructure now uses publisher-based coordination or explicit dependency injection
- Maintains full compatibility with existing test patterns while eliminating sleep-based anti-patterns

## [2025-07-25] - UI Performance: Count-Based Batching

### Added
- **NEW**: Count-based batching for file discovery UI updates to eliminate jank during scanning
- **NEW**: `processFilesStream()` method in FileProcessorService providing AsyncStream<[File]> interface
- **NEW**: `appendFiles()` method in FileStore for batched file additions
- **NEW**: Configurable batch size (default: 50 files) for UI update frequency control

### Changed
- **PERFORMANCE**: File scanning now batches UI updates in groups of 50 files instead of updating per-file
- **ARCHITECTURE**: AppState.startScan() now uses streaming interface with count-based buffering
- **UI**: Dramatically reduced UI update frequency from hundreds/second to ~1 update per 50 files
- **TESTING**: Updated integration tests to handle new batching behavior with appropriate timeouts

### Technical Implementation
- Implemented buffer-based batching in AppState.startScan() following JANK.md specifications
- Added AsyncStream support to FileProcessorService for streaming file processing results
- Enhanced FileStore with append operation for incremental file list building
- Maintained proper MainActor threading for all UI updates via batched MainActor.run blocks

### Performance Impact
- **UI Responsiveness**: Eliminated freezing during large volume scans (tested with 484+ files)
- **Trade-off**: Small volumes (<50 files) now update only when scan completes (accepted design decision)
- **Memory**: Minimal additional memory usage (50-file buffer vs. immediate processing)

### Files Changed
- AppState.swift: Implemented count-based batching logic with 50-file buffer
- FileProcessorService.swift: Added processFilesStream() method returning AsyncStream<[File]>
- FileStore.swift: Added appendFiles() method for batched file additions
- AppStateIntegrationTests.swift: Updated tests for new batching behavior and timing

## [2025-07-23] - Thumbnail Cache Optimization

### Added
- **NEW**: Dual caching system in ThumbnailCache actor storing both JPEG data and SwiftUI Images
- **NEW**: `thumbnailImage(for:)` method providing direct SwiftUI Image access from ThumbnailCache
- **NEW**: Environment injection for ThumbnailCache enabling direct UI access
- **NEW**: Unified LRU eviction managing both data and image caches with single limit

### Removed
- **BREAKING**: Removed legacy `thumbnail(for:)` method from ThumbnailCache
- **PERFORMANCE**: Eliminated all Data→Image conversions from UI layer (MediaFileCellView)

### Changed
- **ARCHITECTURE**: MediaFileCellView now uses ThumbnailCache directly via environment injection
- **PERFORMANCE**: ThumbnailCache generates Images off-main-thread, eliminating UI blocking
- **MEMORY**: Optimized cache eviction to manage both data and image storage efficiently

### Technical Implementation
- Enhanced ThumbnailCache with dual storage: `dataCache` and `imageCache` with unified LRU
- Added SwiftUI environment key for ThumbnailCache dependency injection
- Updated MediaFileCellView to use `thumbnailImage(for:)` directly in async Task
- Maintained JPEG compression (80% quality) for efficient data storage
- Added comprehensive tests for dual caching behavior and performance

### Files Changed
- ThumbnailCache.swift: Added dual caching, environment key, removed legacy API
- MediaFileCellView.swift: Direct ThumbnailCache usage, removed Data→Image conversion
- Media_MuncherApp.swift: Added ThumbnailCache environment injection
- ContentView.swift: Added ThumbnailCache to preview environment
- ThumbnailCacheTests.swift: Updated all tests to use thumbnailImage API, added dual cache tests

### Performance Impact
- **ELIMINATED**: Redundant Data→Image conversions in UI layer
- **IMPROVED**: Thumbnail access speed through direct Image caching
- **MAINTAINED**: Memory efficiency through unified LRU eviction
- **ENHANCED**: UI responsiveness by moving Image conversion off MainActor

### Breaking Changes
- Tests using `cache.thumbnail(for:)` must migrate to `cache.thumbnailImage(for:)`
- ThumbnailCache no longer provides legacy Image conversion method

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
