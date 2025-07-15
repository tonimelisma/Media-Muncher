# Project Structure

## Root Directory Layout
```
Media Muncher/                    # Main app source code
Media Muncher.xcodeproj/          # Xcode project files
Media MuncherTests/               # Test suite with fixtures
Media-Muncher-Info.plist          # App metadata
*.md                              # Documentation files
```

## Main App Structure (`Media Muncher/`)
```
Media_MuncherApp.swift            # App entry point, service injection
AppState.swift                    # Main orchestrator, UI state machine
Media_Muncher.entitlements        # Security permissions

Services/                         # Business logic actors
├── VolumeManager.swift           # Volume discovery and monitoring
├── FileProcessorService.swift    # Media scanning, thumbnail caching
├── ImportService.swift           # File copying and collision handling
├── SettingsStore.swift           # User preferences persistence
└── RecalculationManager.swift    # Destination change state machine

Helpers/                          # Pure utility functions
└── DestinationPathBuilder.swift  # Path generation logic

Models/                           # Value types and data structures
├── VolumeModel.swift             # Volume representation
├── FileModel.swift               # File metadata and status
└── AppError.swift                # Domain-specific errors

Protocols/                        # Interface definitions
└── VolumeManaging.swift          # Volume management protocol

Views/                            # SwiftUI user interface
├── ContentView.swift             # Main window layout
├── VolumeView.swift              # Sidebar volume list
├── MediaView.swift               # Detail pane coordinator
├── MediaFilesGridView.swift      # Adaptive file grid
├── MediaFileCellView.swift       # Individual file cell
├── BottomBarView.swift           # Progress and action bar
├── ErrorView.swift               # Error banner display
├── SettingsView.swift            # Preferences window
└── DestinationFolderPicker.swift # Folder selection UI

Assets.xcassets/                  # App icons and colors
Preview Content/                  # SwiftUI preview assets
```

## Test Structure (`Media MuncherTests/`)
```
*IntegrationTests.swift           # End-to-end tests on real filesystem
*Tests.swift                      # Unit tests for pure logic
Fixtures/                         # Sample media files for testing
├── exif_image.jpg                # Image with EXIF metadata
├── no_exif_image.heic            # Image without EXIF
├── duplicate_a.jpg               # Duplicate detection test files
├── duplicate_b.jpg
├── sidecar_video.mov             # Video with sidecar
└── sidecar_video.THM             # THM sidecar file
Mocks/                            # Test doubles (currently empty)
```

## Architectural Layers

### Service Layer (Actors)
- **VolumeManager**: NSWorkspace integration, volume monitoring
- **FileProcessorService**: File discovery, metadata extraction, thumbnail generation
- **ImportService**: File copying, collision resolution, progress reporting
- **SettingsStore**: UserDefaults wrapper with Combine publishers
- **RecalculationManager**: Handles destination changes with proper state management

### Orchestration Layer
- **AppState**: Coordinates services, manages UI state machine, publishes to SwiftUI

### UI Layer (SwiftUI)
- **NavigationSplitView**: Sidebar + detail pane layout
- **Adaptive grids**: Responsive file display
- **Progress tracking**: Real-time import status
- **Error handling**: Inline banners and alerts

## File Naming Conventions
- **Services**: `*Service.swift` for business logic actors
- **Views**: `*View.swift` for SwiftUI components  
- **Models**: `*Model.swift` for data structures
- **Tests**: `*Tests.swift` for unit tests, `*IntegrationTests.swift` for end-to-end tests
- **Helpers**: Pure functions without dependencies

## Key Dependencies Flow
```
SwiftUI Views → AppState → Services → Foundation/System APIs
```

## Testing Strategy
- **Integration tests**: Primary testing approach using real filesystem
- **Unit tests**: For pure logic like DestinationPathBuilder
- **Fixtures**: Curated media files covering edge cases
- **No mocks**: Prefer real filesystem operations for reliability

## Documentation Files
- **README.md**: Project overview and setup
- **PRD.md**: Product requirements with user stories
- **ARCHITECTURE.md**: Detailed technical architecture
- **CLAUDE.md**: Development commands and guidance
- **UI.md**: SwiftUI component catalog and design patterns