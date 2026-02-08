# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ownership & Accountability

You are the sole engineering agent on this codebase. You own it end-to-end — from requirements through to a passing build on the main branch. There is no other engineer to blame, no "pre-existing issue" to defer to, no "unrelated flaky test" to ignore. If the build is broken, you broke it. If tests fail, you fix them. If there are code smells, temporary files, dead code, or stale documentation — those are your responsibility too.

Be proactive. If you notice something wrong while working on an unrelated task, flag it, fix it, or at minimum create a tracking issue. Do not leave the codebase in a worse state than you found it. Every commit you produce must leave `main` green: building, passing all tests, and ready to ship.

## Definition of Done

A task is not complete until all of the following are true:

1. **Build succeeds**: `xcodebuild -scheme "Media Muncher" build` passes with zero errors and zero warnings you introduced.
2. **All tests pass**: `xcodebuild -scheme "Media Muncher" test` — every single test, not just the ones related to your change. You own the entire suite.
3. **CHANGELOG.md updated**: Every user-visible change, bug fix, or architectural improvement gets a concise entry under the appropriate heading.
4. **Git commit**: Staged, committed with a clear message, and pushed to the remote. The commit must include all modified files — source, tests, documentation, and changelog.
5. **Documentation current**: If your change affects architecture, conventions, or public APIs described in CLAUDE.md or ARCHITECTURE.md, update them in the same commit. See *Self-Maintenance* below.

## Self-Maintenance

This file (CLAUDE.md) is a living document. Every time you make a change to the codebase, evaluate whether CLAUDE.md still accurately reflects reality. Ask yourself:

- Does the architecture section still match the code?
- Are the build/test commands still correct?
- Have any conventions changed that should be reflected here?
- Is this file getting too long? Should something be extracted to ARCHITECTURE.md or a new doc with a reference here?

Keep CLAUDE.md concise and focused on what an agent needs to know to work effectively. Deep dives belong in ARCHITECTURE.md. If CLAUDE.md needs restructuring, do it — don't let it rot.

## Build & Test Commands

```bash
# Build
xcodebuild -scheme "Media Muncher" build

# Run all tests
xcodebuild -scheme "Media Muncher" test

# Run specific test class
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests"

# Run single test method
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests/testBasicImportFlow"
```

This is a native macOS SwiftUI app (not iOS). No signing configuration is needed for local builds.

## Debugging with Logs

The app uses a custom actor-based JSON logging system. A `./logs/` symlink points to `~/Library/Logs/Media Muncher/`.

```bash
# Follow logs in real-time
tail -f logs/media-muncher-*.log

# Filter by category or level with jq
tail -n 100 logs/media-muncher-*.log | jq 'select(.category == "ImportService")'
tail -n 100 logs/media-muncher-*.log | jq 'select(.level == "ERROR")'
```

**Log categories:** `AppState`, `VolumeManager`, `FileProcessor`, `ImportService`, `SettingsStore`, `RecalculationManager`

## Architecture

The app follows an **Orchestrator + Service Actors** pattern: SwiftUI views bind to `AppState`, which delegates to actor-isolated services (`FileProcessorService`, `ImportService`, `VolumeManager`) with `FileStore` as the single owner of file state. All services are wired via constructor injection in `AppContainer` (production) and `TestAppContainer` (tests) — no singletons, no service locator. The `Logging` protocol is injected into every service; never create a `LogManager` directly.

For the full source-code map, service responsibilities, concurrency model, and runtime flows, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Testing

**Integration tests are primary.** Tests use real file system operations with fixtures in `Media MuncherTests/Fixtures/`. Prefer integration tests over mocks for anything touching the file system.

### Test Infrastructure

- **`TestAppContainer`**: Mirrors `AppContainer` with `MockLogManager` and isolated `UserDefaults`.
- **`IntegrationTestCase`**: Base class for file-system integration tests. Creates temp directories and wires up services.
- **`TestDataFactory`**: Factory methods for creating test `File`, `Volume`, and other model instances. Use these instead of calling model initializers directly in tests.
- **`DIConvenience`**: Helper extensions for test service construction.
- **`AsyncTestCoordinator`/`AsyncTestUtilities`**: Helpers for async test coordination without `Task.sleep()`.

### Test Conventions

- Never use `Task.sleep()` in tests — use deterministic coordination instead. See [ASYNC_TEST_PATTERNS.md](ASYNC_TEST_PATTERNS.md) for the setup-then-trigger pattern and working examples.
- Use `recalculatePathsOnly()` for synchronous path calculation tests.
- Logging calls in async contexts use `await logManager.debug(...)`. In non-async contexts (didSet, Combine sinks, init), use `logManager.debugSync(...)` — sync fire-and-forget helpers that internally dispatch to the actor.

## Key Implementation Rules

- **Concurrency**: Actors for file system operations, `@MainActor` only for UI state. `AppContainer` itself is `@MainActor`.
- **Cancellation**: Long operations must check `Task.checkCancellation()`.
- **EXIF dates**: `DateFormatter` forced to UTC to prevent timezone bugs.
- **Security**: Not sandboxed, but uses security-scoped resources defensively. Destination folder stored as a security-scoped bookmark via `BookmarkStore`.
- **Sidecar files**: THM, XMP, LRC are never copied to destination. They are only deleted from source alongside their parent media when deletion is enabled.
- **Duplicate detection**: Date+size heuristic first, streaming CRC32 checksum fallback (1 MB chunks to avoid OOM on large video files).
- **Error handling**: Domain-specific `AppError` enum. Never crash on I/O errors — surface to user via UI banners.

## Supported File Types

- **Photos**: jpg, jpeg, png, heif, heic, tiff, etc.
- **Videos**: mp4, mov, avi, mkv, professional (braw, r3d, ari)
- **Audio**: mp3, wav, aac
- **RAW**: cr2, cr3, nef, arw, dng, etc. (separate filter toggle)
- **Sidecars**: THM, XMP, LRC (auto-managed with parent media)

## Current Status

Core functionality complete: volume management, media discovery, import engine, logging, comprehensive tests (>90% coverage on core logic). Automation/launch agents (Epic 7) not started.
