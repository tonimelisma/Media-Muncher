//
//  RecalculationManager.swift
//  Media Muncher
//
//  Created by Claude on 2025-07-14.
//

import Foundation
import SwiftUI
import Combine

/// Manages the state and logic for recalculating file destination paths
/// when the import destination changes.
/// This class acts as a dedicated state machine for the recalculation process.
@MainActor
class RecalculationManager: ObservableObject {

    // MARK: - Published Properties (for UI binding)

    /// The array of files with their recalculated destination paths and statuses.
    @Published private(set) var files: [File] = []

    /// A boolean indicating whether a recalculation process is currently active.
    /// Used by the UI to show progress indicators.
    @Published private(set) var isRecalculating: Bool = false

    /// An optional error that occurred during the recalculation process.
    @Published private(set) var error: AppError? = nil

    /// Emits once every time a recalculation finishes (success, cancel or error).
    let didFinish = PassthroughSubject<Void, Never>()

    var didFinishPublisher: AnyPublisher<Void, Never> {
        didFinish.eraseToAnyPublisher()
    }

    // MARK: - Dependencies

    /// The service responsible for performing the actual file path calculations and existence checks.
    private let fileProcessorService: FileProcessorService

    /// The settings store, providing user preferences for path organization.
    private let settingsStore: SettingsStore
    
    /// Logging dependency
    private let logManager: Logging

    // MARK: - Internal State

    /// The current task handling the recalculation. Used for cancellation.
    private var currentRecalculationTask: Task<Void, Error>?

    // MARK: - Initialization

    init(logManager: Logging = LogManager(), fileProcessorService: FileProcessorService, settingsStore: SettingsStore) {
        self.logManager = logManager
        self.fileProcessorService = fileProcessorService
        self.settingsStore = settingsStore

        Task.detached {
            let message = "RecalculationManager.init() called - thread: \(Thread.current) - is main thread: \(Thread.isMainThread)"
            await logManager.debug(message, category: "RecalculationManager")
            await logManager.debug("Initialized", category: "RecalculationManager")
        }
    }

    // MARK: - Public API

    /// Initiates the recalculation process for a given set of files and a new destination.
    /// If a recalculation is already in progress, it will be cancelled and a new one started.
    ///
    /// - Parameters:
    ///   - currentFiles: The array of `File` objects that need their paths recalculated.
    ///                   This is typically the `files` array from `AppState`.
    ///   - newDestinationURL: The new destination URL selected by the user.
    ///   - settings: The current application settings, used for path building rules.
    func startRecalculation(
        for currentFiles: [File],
        newDestinationURL: URL?,
        settings: SettingsStore
    ) {
        Task {
            await logManager.debug("startRecalculation called", category: "RecalculationManager", metadata: ["newDestination": newDestinationURL?.path ?? "nil"])
        }

        // 1. Cancel any ongoing recalculation task to handle rapid changes.
        currentRecalculationTask?.cancel()

        // 2. If there are no files to recalculate, just reset state and emit completion.
        guard !currentFiles.isEmpty else {
            Task {
                await logManager.debug("No files to recalculate, resetting state", category: "RecalculationManager")
            }
            self.files = [] // Ensure files are cleared if no files were passed in
            self.isRecalculating = false
            self.error = nil
            self.didFinish.send() // CRITICAL: Always emit completion for test coordination
            return
        }

        // 3. Set the manager's internal files to the current set passed in.
        // This ensures the manager always works with the latest set of files from AppState.
        self.files = currentFiles

        // 4. Update UI state to indicate recalculation is in progress.
        self.isRecalculating = true
        self.error = nil // Clear any previous errors

        // 5. Create and start a new asynchronous task for the recalculation.
        currentRecalculationTask = Task {
            do {
                await logManager.debug("Recalculation task started", category: "RecalculationManager")
                // Perform the actual recalculation using FileProcessorService.
                let recalculatedFiles = await fileProcessorService.recalculateFileStatuses(
                    for: currentFiles, // Use the files passed into the function
                    destinationURL: newDestinationURL,
                    settings: settings // Use the settings passed into the function
                )

                // IMPORTANT: Check for cancellation *before* updating UI state.
                // If the task was cancelled, this line will throw CancellationError.
                try Task.checkCancellation()

                // If we reach here, the recalculation completed successfully and was not cancelled.
                await logManager.debug("Recalculation task completed successfully", category: "RecalculationManager")
                self.files = recalculatedFiles // Update the published files array
                self.isRecalculating = false // Reset recalculating flag
                self.error = nil // Ensure no error is shown
                self.didFinish.send()
            } catch is CancellationError {
                // This block is executed if the task was explicitly cancelled (e.g., by a new destination change).
                await logManager.debug("Recalculation task was cancelled", category: "RecalculationManager")
                self.isRecalculating = false // Reset recalculating flag
                self.error = nil
                self.didFinish.send()
            } catch {
                // This block handles any other unexpected errors during recalculation.
                await logManager.error("Recalculation task failed", category: "RecalculationManager", metadata: ["error": error.localizedDescription])
                self.isRecalculating = false // Reset recalculating flag
                self.error = .recalculationFailed(reason: error.localizedDescription)
                self.didFinish.send()
            }
        }
    }

    /// Cancels any ongoing recalculation task.
    func cancelRecalculation() {
        Task {
            await logManager.debug("cancelRecalculation called", category: "RecalculationManager")
        }
        currentRecalculationTask?.cancel()
        self.isRecalculating = false // Ensure state is reset immediately
        self.error = nil
        didFinish.send()
    }
    
    /// Updates the internal files array. Used by AppState to sync newly scanned files.
    func updateFiles(_ newFiles: [File]) {
        Task {
            await logManager.debug("updateFiles called", category: "RecalculationManager", metadata: ["count": "\(newFiles.count)"])
        }
        self.files = newFiles
    }
}