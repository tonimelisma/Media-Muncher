# Technology Stack

## Platform & Requirements
- **Platform**: macOS 13+ (Ventura and later)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: Actor-based concurrency with Combine publishers
- **Deployment Target**: macOS 13.0

## Core Frameworks
- **SwiftUI**: Primary UI framework
- **Combine**: Reactive data flow and state management
- **AVFoundation**: Video metadata extraction
- **QuickLookThumbnailing**: Thumbnail generation with LRU cache (2000 entries)
- **CryptoKit**: SHA-256 checksums for duplicate detection fallback
- **NSWorkspace**: Volume detection and monitoring
- **Foundation**: File system operations, UserDefaults persistence

## Build System
- **Xcode Project**: Standard .xcodeproj (no Swift Package Manager dependencies)
- **Build Tool**: Xcode 15+ or xcodebuild command line
- **Code Quality**: swiftformat and swiftlint integration

## Common Commands

### Building
```bash
# Open in Xcode
open "Media Muncher.xcodeproj"

# Build from command line
xcodebuild -scheme "Media Muncher" build

# Clean build
xcodebuild -scheme "Media Muncher" clean build
```

### Testing
```bash
# Run all tests
xcodebuild -scheme "Media Muncher" test

# Run specific test class
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests"

# Run single test method
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests/testBasicImportFlow"
```

### Development Setup
```bash
# Install Xcode command line tools
xcode-select --install

# Install code quality tools
brew install swiftformat swiftlint
```

## Architecture Patterns
- **Actor-based concurrency**: File operations run on background actors
- **Service-oriented**: Focused services with single responsibilities
- **Combine publishers**: State changes via @Published properties
- **MainActor**: UI updates only on main thread
- **Task cancellation**: Long operations support cancellation

## Security Model
- **App Sandbox**: Enabled with specific entitlements
- **Entitlements**: Removable drives, user-selected files read/write
- **Security-scoped bookmarks**: Destination folder access persistence
- **No plain file paths**: Stored outside sandbox container

## Performance Targets
- Import throughput: ≥200 MB/s (hardware limited)
- UI responsiveness: Never block main thread
- Memory efficiency: LRU thumbnail cache prevents unbounded growth
- Test coverage: >90% on core logic