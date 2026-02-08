# Media Muncher

A lightweight macOS utility that automatically imports photographs, videos, and audio recordings from removable storage (SD cards, USB disks, connected cameras) into a user-defined library structure. It handles date-based organization, duplicate detection, sidecar file management, and safe deletion of originals — designed for photographers and videographers who ingest cards daily.

## Status

Core functionality is complete: volume management, media discovery with thumbnails, import engine with progress tracking, settings persistence, and comprehensive logging. Automation/launch agents (Epic 7) are not yet started — see [launchd.md](launchd.md) for research.

## Build & Test

```bash
# Build
xcodebuild -scheme "Media Muncher" build

# Run all tests
xcodebuild -scheme "Media Muncher" test
```

This is a native macOS SwiftUI app (not iOS). No signing configuration is needed for local builds. See [CLAUDE.md](CLAUDE.md) for full build/test commands, debugging with logs, and development conventions.

## Documentation

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Agent operating manual — ownership, definition of done, build/test, conventions |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design — source map, concurrency model, DI, runtime flows |
| [PRD.md](PRD.md) | Product requirements and epic/story status tracking |
| [UI.md](UI.md) | View catalogue and UI component details |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [ASYNC_TEST_PATTERNS.md](ASYNC_TEST_PATTERNS.md) | Async testing patterns reference |
| [launchd.md](launchd.md) | Research doc for future volume automation (Epic 7) |
