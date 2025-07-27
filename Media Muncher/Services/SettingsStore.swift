import Foundation
import SwiftUI

/// Service responsible for user preference persistence and reactive state management.
/// 
/// ## Async Pattern: ObservableObject + Combine Publishers + Security-Scoped Resources
/// This service uses ObservableObject with @Published properties for reactive UI updates.
/// File system validation operations are synchronous but could be made async in the future.
/// Uses security-scoped resources defensively for folder access validation.
/// 
/// ## Usage Pattern:
/// ```swift
/// // From SwiftUI Views (reactive binding)
/// @EnvironmentObject var settingsStore: SettingsStore
/// Toggle("Delete Originals", isOn: $settingsStore.settingDeleteOriginals)
/// 
/// // From AppState (reactive subscription)
/// settingsStore.$destinationURL
///     .receive(on: DispatchQueue.main)
///     .sink { newDestination in
///         // Trigger recalculation
///     }
///     .store(in: &cancellables)
/// ```
/// 
/// ## Responsibilities:
/// - Persist user preferences via UserDefaults
/// - Validate destination folder write access
/// - Provide reactive updates for setting changes
/// - Handle security-scoped resource access for folder permissions
class SettingsStore: ObservableObject {
    private let userDefaults: UserDefaults
    private let logManager: Logging
    
    @Published var settingDeleteOriginals: Bool {
        didSet {
            Task {
                await logManager.debug("settingDeleteOriginals changed", category: "SettingsStore", metadata: ["value": "\(settingDeleteOriginals)"])
            }
            userDefaults.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }

    @Published var organizeByDate: Bool {
        didSet {
            Task {
                await logManager.debug("organizeByDate changed", category: "SettingsStore", metadata: ["value": "\(organizeByDate)"])
            }
            userDefaults.set(organizeByDate, forKey: "organizeByDate")
        }
    }
    
    @Published var renameByDate: Bool {
        didSet {
            Task {
                await logManager.debug("renameByDate changed", category: "SettingsStore", metadata: ["value": "\(renameByDate)"])
            }
            userDefaults.set(renameByDate, forKey: "renameByDate")
        }
    }

    @Published var filterImages: Bool {
        didSet {
            Task {
                await logManager.debug("filterImages changed", category: "SettingsStore", metadata: ["value": "\(filterImages)"])
            }
            userDefaults.set(filterImages, forKey: "filterImages")
        }
    }

    @Published var filterVideos: Bool {
        didSet {
            Task {
                await logManager.debug("filterVideos changed", category: "SettingsStore", metadata: ["value": "\(filterVideos)"])
            }
            userDefaults.set(filterVideos, forKey: "filterVideos")
        }
    }

    @Published var filterAudio: Bool {
        didSet {
            Task {
                await logManager.debug("filterAudio changed", category: "SettingsStore", metadata: ["value": "\(filterAudio)"])
            }
            userDefaults.set(filterAudio, forKey: "filterAudio")
        }
    }

    @Published var filterRaw: Bool {
        didSet {
            Task {
                await logManager.debug("filterRaw changed", category: "SettingsStore", metadata: ["value": "\(filterRaw)"])
            }
            userDefaults.set(filterRaw, forKey: "filterRaw")
        }
    }

    @Published var settingAutoEject: Bool {
        didSet {
            Task {
                await logManager.debug("settingAutoEject changed", category: "SettingsStore", metadata: ["value": "\(settingAutoEject)"])
            }
            userDefaults.set(settingAutoEject, forKey: "settingAutoEject")
        }
    }

    
    @Published private(set) var destinationURL: URL? {
        didSet {
            Task {
                await logManager.debug("destinationURL changed", category: "SettingsStore", metadata: ["path": destinationURL?.path ?? "nil"])
            }
        }
    }


    init(logManager: Logging = LogManager(), userDefaults: UserDefaults = .standard) {
        self.logManager = logManager
        self.userDefaults = userDefaults
        
        self.settingDeleteOriginals = userDefaults.bool(forKey: "settingDeleteOriginals")
        self.organizeByDate = userDefaults.bool(forKey: "organizeByDate")
        self.renameByDate = userDefaults.bool(forKey: "renameByDate")
        self.settingAutoEject = userDefaults.bool(forKey: "settingAutoEject")
        
        // Default to true if no value is set
        self.filterImages = userDefaults.object(forKey: "filterImages") as? Bool ?? true
        self.filterVideos = userDefaults.object(forKey: "filterVideos") as? Bool ?? true
        self.filterAudio = userDefaults.object(forKey: "filterAudio") as? Bool ?? true
        self.filterRaw = userDefaults.object(forKey: "filterRaw") as? Bool ?? true

        // Set destination synchronously - no async operations in constructor
        self.destinationURL = Self.computeDefaultDestination()
        
        // Log initialization asynchronously (fire-and-forget)
        Task {
            await logManager.debug("SettingsStore initialized", category: "SettingsStore", 
                                  metadata: ["destinationURL": destinationURL?.path ?? "nil"])
        }
    }


    // MARK: - Default Destination Computation
    
    /// Computes the default destination directory synchronously
    /// Checks Pictures folder first, then Documents, returns nil if neither exists
    private static func computeDefaultDestination() -> URL? {
        let homeDirectory = NSHomeDirectory()
        let picturesURL = URL(fileURLWithPath: homeDirectory).appendingPathComponent("Pictures")
        
        if FileManager.default.fileExists(atPath: picturesURL.path) {
            return picturesURL
        }
        
        let documentsURL = URL(fileURLWithPath: homeDirectory).appendingPathComponent("Documents")
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            return documentsURL
        }
        
        return nil
    }

    // MARK: - Preset Folder Helpers
    private static let presetFolderNames: [String] = [
        "Pictures", "Movies", "Music", "Desktop", "Documents", "Downloads"
    ]

    private func isPresetFolder(_ url: URL) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return SettingsStore.presetFolderNames.contains {
            url.standardizedFileURL == home.appendingPathComponent($0).standardizedFileURL
        }
    }
 
    /// Attempts to set the given URL as the destination folder.
    /// - Returns: `true` if the app has confirmed write access *and* (for custom folders) managed to create a bookmark; `false` otherwise.
    @discardableResult
    func trySetDestination(_ url: URL) -> Bool {
        Task {
            await logManager.debug("trySetDestination called", category: "SettingsStore", metadata: ["path": url.path])
        }

        // Validate the URL exists & is a directory.
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            Task {
                await logManager.error("Invalid directory", category: "SettingsStore", metadata: ["path": url.path])
            }
            return false
        }

        // Quick write-test to confirm sandbox/TCC access.
        let testFile = url.appendingPathComponent(".mm_write_test_\(UUID().uuidString)")
        do {
            try Data().write(to: testFile)
            try fm.removeItem(at: testFile)
        } catch {
            Task {
                await logManager.error("Write-test failed", category: "SettingsStore", metadata: ["error": error.localizedDescription])
            }
            return false
        }

        // All good – commit the new URL. This is the ONLY assignment to destinationURL now.
        destinationURL = url
        return true
    }

    func setDestination(_ url: URL) {
        _ = trySetDestination(url)
    }
    

} 