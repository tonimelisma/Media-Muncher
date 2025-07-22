# DI Container & Refactoring

This document describes the dependency injection (DI) strategy and tracks the refactoring work completed to improve the app's architecture.

## DI Container: `AppContainer`

The `AppContainer` is a simple, plain Swift class that acts as a factory for all services. It follows the "Composition Root" pattern.

- **Purpose**: To instantiate and wire up all services, creating a single, coherent dependency graph.
- **Implementation**: It has an `async` initializer to allow for services that need to be created on the Main Actor. It provides a `static func blocking()` method for use in the `App`'s synchronous `init`.
- **Location**: `Media Muncher/AppContainer.swift`

## Key Architectural Improvements

This section tracks the resolution of architectural smells identified in the initial codebase.

### 1. Massive `AppState` - RESOLVED

- **Problem**: `AppState` was a "god object" containing all application logic, state, and service interactions.
- **Solution**:
    - Logic was extracted into dedicated services (e.g., `FileProcessorService`, `ImportService`).
    - `AppState` now acts as a pure **orchestrator**, delegating work and managing high-level UI state.
    - All services are now `private` within `AppState` to enforce encapsulation.

### 2. `MainActor` Misuse - RESOLVED

- **Problem**: The DI container (`AppContainer`) was marked `@MainActor`, forcing all service initializations to happen on the main thread, even for services that do background work.
- **Solution**:
    - `@MainActor` was removed from `AppContainer`.
    - The `AppContainer` initializer is now `async`.
    - Services that require the main thread (like `FileStore` and `RecalculationManager`) are `await`-ed during initialization.
    - A `static func blocking()` factory method was added to `AppContainer` to bridge the `async` initializer to the synchronous `App` lifecycle.

### 3. Brittle Tests via Direct Service Access - RESOLVED

- **Problem**: Tests directly accessed service properties on `AppState` (e.g., `appState.settingsStore`), creating tight coupling and making tests brittle.
- **Solution**:
    - Service properties on `AppState` were made `private`.
    - A `TestAppContainer` was introduced to provide a consistent dependency setup for integration tests.
    - Tests were refactored to rely on the public, observable state of the system (e.g., `@Published` properties) rather than implementation details. This makes tests more robust and user-centric.

### 4. Hybrid `async` Logging with Completion Handlers - RESOLVED

- **Problem**: `LogManager` used a `nonisolated` `write` function with a `@Sendable` completion handler, a hybrid pattern that is a code smell in a modern Swift Concurrency codebase.
- **Solution**:
    - The `Logging` protocol and `LogManager`'s `write` function were converted to be `async`.
    - All call sites were updated to use `await`, removing the need for completion handlers and `Task` wrappers in many places.
    - The `MockLogManager` and all relevant tests were updated to use the pure `async` API.

### 5. `FileStore` Single Responsibility Principle Violation - RESOLVED

- **Problem**: `FileStore` was responsible for both managing the `files` array and generating thumbnails, violating the Single Responsibility Principle.
- **Solution**:
    - A dedicated `ThumbnailCache` actor was created to handle all thumbnail generation and caching logic, offloading it from the main thread.
    - `FileStore` is now only responsible for managing the state of the `files` array.

## Conclusion

The codebase is now in a much healthier state. The separation of concerns is clear, the use of Swift Concurrency is more idiomatic, and the tests are more robust and less coupled to implementation details. 