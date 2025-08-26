# Repository Guidelines

This guide helps contributors work effectively on Media Muncher.

## Project Structure & Modules
- `Media Muncher/`: SwiftUI app sources (views, models, services).
- `Media Muncher/Services/`: Core logic (volume scanning, importing, logging).
- `Media MuncherTests/`: XCTest suites with fixtures and test support.
- `Media Muncher.xcodeproj`: Xcode project; primary scheme `Media Muncher`.
- `logs/`: Symlink to `~/Library/Logs/Media Muncher` for runtime logs.
- See `ARCHITECTURE.md` and `UI.md` for deeper overview.

## Build, Test, and Run
- Build (CLI): `xcodebuild -scheme "Media Muncher" build`
- Test (all): `xcodebuild -scheme "Media Muncher" test`
- Test (class): `xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherTests/ImportServiceIntegrationTests"`
- Open in Xcode: `open "Media Muncher.xcodeproj"` (then Run with ⌘R, Test with ⌘U)
- View logs: `tail -f logs/media-muncher-*.log`

## Coding Style & Naming
- Language: Swift 5; indent 4 spaces; prefer explicit access control.
- Types `PascalCase`; methods/vars `lowerCamelCase`; files match main type name.
- Prefer small, focused services; UI on `MainActor`, async work off main.
- Tools: SwiftFormat and SwiftLint (install via Homebrew). Keep PRs formatted and lint-clean.

## Testing Guidelines
- Framework: XCTest. Favor integration tests (real file system fixtures) with targeted unit tests for pure logic.
- Names: Test files end with `Tests.swift`; test methods start with `test…`.
- Coverage: Maintain strong coverage on core services (target ≥70% overall; current core >90%).
- Examples:
  - Single method: `-only-testing:"Media MuncherTests/ImportServiceIntegrationTests/testBasicImportFlow"`

## Commit & Pull Requests
- Commits: Imperative, concise summaries (e.g., "Fix grid column calculation"). Group related changes; reference issues (e.g., `#123`).
- PRs: Clear description, why + how, linked issues, test plan, and screenshots/GIFs for UI. Include notes on logging or migration if relevant.
- CI/local: Ensure build and tests pass via the scheme above; run formatter/linter before opening PRs.

## Security & Configuration
- Removable volume access uses security-scoped resources; avoid hardcoding paths. Use `SettingsStore` APIs.
- Logs live under `~/Library/Logs/Media Muncher/` and rotate automatically. Don’t commit logs.
- When touching import paths, use `DestinationPathBuilder` to handle collisions and date-based organization consistently.

