# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start Commands

### Building and Testing
```bash
# Open project in Xcode
open "Media Muncher.xcodeproj"

# Build from command line
xcodebuild -scheme "Media Muncher" build

# Run all tests
xcodebuild -scheme "Media Muncher" test

# Run specific test class
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests"

# Run single test method
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests/testBasicImportFlow"
```

### Development Setup
```bash
# Install required tools (mentioned in ARCHITECTURE.md)
xcode-select --install
brew install swiftformat swiftlint jq  # jq for JSON log filtering

# Build and run (use Xcode or press ⌘R)
# Run tests (press ⌘U in Xcode)
```

### Debugging with LogManager
Media Muncher uses a custom JSON-based logging system for structured debug output and persistent logging. Use these commands to capture and analyze logs during development and testing:

```bash
# View recent logs (recommended for debugging)
tail -n 50 ~/Library/Logs/Media\ Muncher/app.log

# Follow logs in real-time during development
tail -f ~/Library/Logs/Media\ Muncher/app.log

# Filter by category using jq (install with: brew install jq)
tail -n 100 ~/Library/Logs/Media\ Muncher/app.log | jq 'select(.category == "FileProcessor")'

# Debug failing tests by running test then viewing logs
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/AppStateRecalculationTests/testRecalculationHandlesRapidDestinationChanges"
tail -n 20 ~/Library/Logs/Media\ Muncher/app.log

# Filter by log level
tail -n 100 ~/Library/Logs/Media\ Muncher/app.log | jq 'select(.level == "error")'

# Search for specific terms
grep "Processing file" ~/Library/Logs/Media\ Muncher/app.log

# Show logs from last hour with metadata
tail -n 500 ~/Library/Logs/Media\ Muncher/app.log | jq 'select(.timestamp > "'$(date -u -v-1H +%Y-%m-%dT%H:%M:%S)'.000Z")'
```

**Log Categories Available:**
- `AppState`: Main application state and lifecycle events
- `VolumeManager`: Disk mount/unmount and volume discovery
- `FileProcessor`: File scanning and metadata processing
- `ImportService`: File copy/delete operations and progress
- `SettingsStore`: User preference changes
- `RecalculationManager`: Destination path recalculation events

**Log Location:** `~/Library/Logs/Media Muncher/media-muncher-YYYY-MM-DD_HH-mm-ss-<pid>.log` (one file per process, files older than 30 days are automatically deleted at startup)

**Convenient Log Access:** The project includes a symbolic link `./logs/` that points to the log directory, allowing easy access with standard tools:
```bash
# Browse log files
ls logs/

# View recent entries
cat logs/media-muncher-2025-07-20_21-55-06-19965.log

# Real-time monitoring
tail -f logs/media-muncher-*.log
```

For detailed architecture information, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Testing Strategy

**Integration Tests (Primary)**: Tests run against real file system using fixtures in `Media MuncherTests/Fixtures/`. The `ImportServiceIntegrationTests` class validates the entire import pipeline from file discovery through copying/deletion.

**Unit Tests (Targeted)**: Used only for pure business logic like `DestinationPathBuilder` that doesn't touch the file system. Now includes synchronous path calculation tests using `recalculatePathsOnly()` for fast, deterministic testing.

**Test Coverage**: Currently >90% on core logic (exceeds 70% requirement from PRD). All tests are confirmed free of `Task.sleep()` operations for improved reliability and deterministic execution.

## Key Implementation Details

### File Processing Pipeline
1. **Discovery**: FileProcessorService recursively scans volume for supported media types
2. **Metadata extraction**: EXIF date parsing (forced UTC), file size calculation
3. **Duplicate detection**: Uses date+size heuristic, falls back to SHA-256 checksum
4. **Thumbnail generation**: Async thumbnail cache (2000 entry LRU) via QuickLookThumbnailing
5. **Pre-existing detection**: Compares against destination using DestinationPathBuilder logic
6. **Path recalculation**: Automatic destination path updates when settings change, with sync/async architecture split

### Import Pipeline
1. **Path calculation**: DestinationPathBuilder generates ideal destination paths
2. **Collision resolution**: Numerical suffixes added before any copying begins
3. **File copying**: Preserves modification and creation timestamps
4. **Sidecar handling**: THM, XMP, LRC files are copied and deleted with parent media
5. **Source cleanup**: Original files deleted only after successful copy (if enabled)

### Supported File Types
- **Photos**: jpg, jpeg, png, heif, heic, tiff, and other image formats
- **Videos**: mp4, mov, avi, mkv, professional formats (braw, r3d, ari)  
- **Audio**: mp3, wav, aac
- **RAW**: cr2, cr3, nef, arw, dng, and other RAW camera formats (separate filtering)
- **Sidecars**: THM, XMP, LRC files automatically managed with parent media

### Settings and Preferences
- Destination folder with write-access validation
- File organization: date-based subfolders (YYYY/MM/)
- File renaming: capture date-based filenames
- File type filters: enable/disable photos/videos/audio/RAW files separately
- Delete originals after import
- Auto-eject volume after import

## Important Constraints

### Security Model
- Application is **not sandboxed** for simplified file access.
- **Security-scoped resources** are used defensively for removable volumes and user-selected destination folders. This means the app only ever gains access to the specific folders you choose, and nothing else.

### Performance Requirements  
- Import throughput ≥200 MB/s (hardware limited)
- UI remains responsive during all operations
- Async/await with proper cancellation support

### Error Handling
- Domain-specific `AppError` enum with context
- Never crash on I/O errors - surface to user
- Read-only volume support (shows banner, continues import)

## Development Notes

- **Concurrency**: Use actors for file system operations, MainActor only for UI updates
- **Testing**: Prefer integration tests over mocks for file system code
- **Path logic**: Always use DestinationPathBuilder for consistency
- **Cancellation**: Long operations must check `Task.checkCancellation()`
- **Thumbnails**: LRU cache prevents memory growth on large volumes
- **EXIF parsing**: DateFormatter forced to UTC to prevent timezone bugs

## Current Status (Per PRD)

Core functionality is **Finished** including volume management, media discovery, import engine, and comprehensive testing. Remaining work includes logging infrastructure (Epic 8) and automation/launch agents (Epic 7).