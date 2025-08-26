# Media Muncher – Re-Architecture Plan (Break Compatibility)

## Why We’re Doing This
- Centralize logging through a single, shared logger for reliability, performance, and simpler debugging.
- Make dependencies explicit (no hidden defaults) to improve testability and avoid accidental multiple logger instances.
- Persist the destination folder as a security-scoped bookmark so the app restores a valid destination across launches.
- Clarify and enforce sidecar file policy: never copy sidecars; delete them from source with their parent media if deletion is enabled.
- Remove responsibility confusion: FileProcessorService is the single source of truth for destination path calculation; ImportService only executes file operations.
- Fix documentation inconsistencies (rename format, logging file paths, sidecar behavior, and test container references).

This is a break-the-API change: constructors and docs will change. We will update AppContainer and references accordingly. Test code will also need updates (follow-up).

## High-Level Objectives
1. Centralize logging: pass exactly one `LogManager` everywhere via DI; remove default `= LogManager()` constructor parameters.
2. Refactor `ThumbnailCache` to accept a `Logging` dependency and remove per-call `LogManager()` creation.
3. Add bookmark persistence for the destination folder; resolve on startup.
4. Enforce sidecar delete-only behavior in docs (code already deletes sidecars; we keep that behavior).
5. Align documentation (PRD, ARCHITECTURE, CLAUDE, UI) with the real code and new policies.

## What Exactly Changes

### 1) Centralized Logging
- Remove default logger parameters from these initializers:
  - `VolumeManager(logManager: Logging)`
  - `SettingsStore(logManager: Logging, userDefaults: UserDefaults)`
  - `ImportService(logManager: Logging, urlAccessWrapper: SecurityScopedURLAccessWrapperProtocol = ...)`
  - `FileProcessorService(logManager: Logging, thumbnailCache: ThumbnailCache)`
  - `RecalculationManager(logManager: Logging, fileProcessorService: FileProcessorService, settingsStore: SettingsStore)`
- AppContainer constructs exactly one `LogManager` and passes it to all services, including `ThumbnailCache`.
- Remove any ad‑hoc `LogManager()` creation in production code.

### 2) ThumbnailCache logging DI
- Change `ThumbnailCache` to require a `Logging` dependency in its initializer: `init(limit: Int = Constants.thumbnailCacheLimit, logManager: Logging)`.
- Replace the per-call `LogManager()` inside `generateThumbnailData` with the injected logger.

### 3) Destination Bookmark Persistence
- Add a new `BookmarkStore` utility:
  - `createBookmark(for url: URL, securityScoped: Bool) -> Data`
  - `resolveBookmark(_ data: Data) -> URL?`
- Update `SettingsStore`:
  - On init: attempt to load bookmark data from `UserDefaults` (key: `destinationBookmark`), resolve to URL if present; else fall back to default destination computation.
  - On `trySetDestination(_:)`: write-test; if OK and not preset folder, create a (security-scoped) bookmark and store to `UserDefaults` along with a string path for diagnostics; then set `destinationURL`.
  - Keep using transient security-scoped access only in `ImportService` during import.

### 4) Sidecar Policy (Delete-Only)
- Code already deletes sidecars from source alongside the parent file when deletion is enabled. We will:
  - Update docs to explicitly state: never copy sidecars to destination; delete them from source only.

### 5) Documentation Updates
- PRD.md:
  - Clarify sidecar policy (delete-only).
  - Update security/bookmarks to reflect destination bookmark persistence at runtime startup.
  - Align rename format in examples to `YYYYMMDD_HHMMSS.ext`.
  - Move “Recent Implementation Notes” into CHANGELOG (keep a short pointer).
- ARCHITECTURE.md:
  - Update module responsibilities (thumbnail cache lives in `ThumbnailCache`, not FileProcessorService; ImportService uses precomputed `destPath`).
  - Add sections “Destination Path Flow” and “Thumbnail Flow via ThumbnailCache”.
  - Clarify test container location: `Media MuncherTests/TestSupport/TestAppContainer.swift`.
- CLAUDE.md:
  - Fix all logging examples to use `logs/media-muncher-*.log` and the real rotated filenames.
  - Align current status (Automation pending; Logging complete).
  - Sidecar policy: delete-only.
- UI.md:
  - Correct `FolderPickerView` → `DestinationFolderPicker`.
  - Fix rename helper text to `YYYYMMDD_HHMMSS.ext`.
  - Note `ThumbnailCache` is provided via SwiftUI environment.

## Acceptance Criteria
- One shared `LogManager` instance is created and injected everywhere via AppContainer.
- No `LogManager()` is created inside services (including `ThumbnailCache`).
- `SettingsStore` persists and resolves destination bookmarks across app launches; fallback default still works.
- Docs consistently reflect sidecar delete-only policy, rename format, and logging filenames.
- ImportService expects `destPath` to be set and handles absence gracefully (skip/fail with clear reason).

## Non-Goals (for now)
- Auto-import/automation flows remain “Not Started”.
- Source (removable volume) bookmark persistence (policy under consideration; transient access remains via ImportService).

## Risks & Mitigations
- Constructor churn across services/tests: Update AppContainer now; plan follow-up to update tests.
- Bookmark behavior in non-sandbox apps: Bookmarks persist paths reliably; `startAccessing…` remains defensive in ImportService; document nuance.
- Logger throughput: Consider reducing noisy logs or gating behind DEBUG later if needed.

## Step-by-Step Tasks
1) Update docs (PRD/ARCH/CLAUDE/UI) per above.
2) Add `BookmarkStore` for bookmark create/resolve.
3) Refactor `SettingsStore` to load/save destination bookmark and set `destinationURL` accordingly.
4) Refactor `ThumbnailCache` to accept `Logging` and remove internal `LogManager()` creation.
5) Remove default logger parameters from service initializers; enforce explicit DI.
6) Update `AppContainer` to construct single `LogManager`, pass to all services including `ThumbnailCache`.
7) Ensure ImportService assumes `destPath` is provided (no path calc) and reacts if missing.
8) Build/lint/test (follow-up in this repo and tests repo if needed).

## Appendix: Reference Behaviors (Today vs After)
- Sidecars: Today delete-only; After delete-only (documented).
- Rename format: Today `YYYYMMDD_HHMMSS`; After same (docs aligned).
- Logging files: Today rotated JSON files; After same (docs aligned, DI enforced).
- Path calc: Today primarily in FileProcessorService; After enforced contract (ImportService does not recalc).

