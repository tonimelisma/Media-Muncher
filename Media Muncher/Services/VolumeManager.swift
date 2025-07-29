//
//  VolumeManager.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Foundation
import SwiftUI

/// Service responsible for volume discovery, monitoring, and ejection.
/// 
/// ## Async Pattern: ObservableObject + Combine Publishers
/// This service uses ObservableObject and @Published properties to provide reactive
/// volume state updates to SwiftUI views. Volume operations are synchronous but
/// monitoring happens via NSWorkspace notifications on the main queue.
/// 
/// ## Usage Pattern:
/// ```swift
/// // From SwiftUI Views
/// @EnvironmentObject var volumeManager: VolumeManager
/// 
/// // From AppState (reactive subscription)
/// volumeManager.$volumes
///     .receive(on: DispatchQueue.main)
///     .sink { newVolumes in
///         // Handle volume changes
///     }
///     .store(in: &cancellables)
/// ```
/// 
/// ## Responsibilities:
/// - Discover removable volumes on system startup
/// - Monitor volume mount/unmount events via NSWorkspace
/// - Filter for removable volumes only (excludes internal drives)
/// - Provide safe volume ejection functionality
class VolumeManager: ObservableObject {
    @Published var volumes: [Volume] = []
    
    private var workspace: NSWorkspace = NSWorkspace.shared
    private var observers: [NSObjectProtocol] = []
    private let logManager: Logging

    init(logManager: Logging = LogManager()) {
        self.logManager = logManager
        Task {
            await logManager.debug("Initializing VolumeManager", category: "VolumeManager")
        }
        self.volumes = loadVolumes()
        Task {
            await logManager.debug("Initial volumes loaded", category: "VolumeManager", metadata: ["count": "\(self.volumes.count)"])
        }
        setupVolumeObservers()
    }

    deinit {
        // Don't use async logging in deinit - it can cause retain cycles
        removeVolumeObservers()
    }
    
    /// Sets up observers for volume mount and unmount events.
    private func setupVolumeObservers() {
        Task {
            await logManager.debug("Setting up volume observers", category: "VolumeManager")
        }
        
        let mountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.logManager.debug("Volume mounted notification received", category: "VolumeManager", metadata: ["notification": "\(notification)"])
            }
            
            guard let userInfo = notification.userInfo,
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                Task {
                    await self?.logManager.error("Couldn't get volume URL from mounting notification", category: "VolumeManager", metadata: ["userInfo": "\(notification.userInfo ?? [:])"])
                }
                return
            }
            Task {
                await self?.logManager.debug("Mounted volume URL", category: "VolumeManager", metadata: ["path": volumeURL.path])
            }

            guard
                let resources = try? volumeURL.resourceValues(forKeys: [
                    .volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey,
                ]),
                let uuid = resources.volumeUUIDString,
                let volumeName = userInfo[
                    NSWorkspace.localizedVolumeNameUserInfoKey] as? String
            else {
                Task {
                    await self?.logManager.error("Couldn't get UUID, localized name and other resources from mounting notification", category: "VolumeManager", metadata: ["availableResources": "\(String(describing: try? volumeURL.resourceValues(forKeys: [.volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey])))"])
                }
                return
            }

            Task {
                await self?.logManager.debug("Volume details", category: "VolumeManager", metadata: [
                    "uuid": uuid,
                    "name": volumeName,
                    "isRemovable": "\(resources.volumeIsRemovable == true)"
                ])
            }

            guard resources.volumeIsRemovable == true else {
                Task {
                    await self?.logManager.debug("Not a removable volume, skipping", category: "VolumeManager")
                }
                return
            }

            let newVolume: Volume = Volume(
                name: volumeName, devicePath: volumeURL.path,
                volumeUUID: uuid)

            Task {
                await self?.logManager.debug("Adding new volume", category: "VolumeManager", metadata: ["volume": "\(newVolume)"])
            }
            self?.volumes.append(newVolume)
            Task {
                await self?.logManager.debug("Total volumes after addition", category: "VolumeManager", metadata: ["count": "\(self?.volumes.count ?? 0)"])
            }
        }

        let unmountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.logManager.debug("Volume unmounted notification received", category: "VolumeManager", metadata: ["notification": "\(notification)"])
            }
            
            guard let userInfo = notification.userInfo else {
                Task {
                    await self?.logManager.error("Couldn't get userInfo from unmounting notification", category: "VolumeManager")
                }
                return
            }

            guard
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                Task {
                    await self?.logManager.error("Couldn't get volume URL from unmounting notification", category: "VolumeManager", metadata: ["userInfo": "\(userInfo)"])
                }
                return
            }
            Task {
                await self?.logManager.debug("Unmounted volume URL", category: "VolumeManager", metadata: ["path": volumeURL.path])
            }

            let removedCount = self?.volumes.count ?? 0
            self?.volumes.removeAll { $0.devicePath == volumeURL.path }
            let remainingCount = self?.volumes.count ?? 0
            Task {
                await self?.logManager.debug("Removed volume", category: "VolumeManager", metadata: ["countBefore": "\(removedCount)", "countAfter": "\(remainingCount)"])
            }
        }

        self.observers.append(mountObserver)
        self.observers.append(unmountObserver)
        Task {
            await logManager.debug("Volume observers set up successfully", category: "VolumeManager")
        }
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        // Don't use async logging during deallocation - it can cause retain cycles
        self.observers.forEach {
            workspace.notificationCenter.removeObserver($0)
        }
        self.observers.removeAll()
    }

    /// Loads all removable volumes connected to the system.
    /// - Returns: An array of `Volume` objects representing the removable volumes.
    func loadVolumes() -> [Volume] {
        Task {
            await logManager.debug("loadVolumes called", category: "VolumeManager")
        }
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeIsRemovableKey,
        ]
        
        guard
            let mountedVolumeURLs = fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: keys,
                options: [.skipHiddenVolumes])
        else {
            Task {
                await logManager.error("Failed to get mounted volume URLs", category: "VolumeManager")
            }
            return []
        }
        
        Task {
            await logManager.debug("Found mounted volumes", category: "VolumeManager", metadata: ["count": "\(mountedVolumeURLs.count)"])
        }

        let volumes = mountedVolumeURLs.compactMap { url -> Volume? in
            Task {
                await logManager.debug("Examining volume", category: "VolumeManager", metadata: ["path": url.path])
            }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                Task {
                    await logManager.debug("Resource values", category: "VolumeManager", metadata: ["path": url.path, "values": "\(resourceValues)"])
                }
                
                guard resourceValues.volumeIsRemovable == true else {
                    Task {
                        await logManager.debug("Volume is not removable, skipping", category: "VolumeManager", metadata: ["path": url.path])
                    }
                    return nil
                }
                
                let volumeName = resourceValues.volumeName ?? "Unnamed Volume"
                let volumeUUID = resourceValues.volumeUUIDString ?? ""
                
                Task {
                    await logManager.debug("Found removable volume", category: "VolumeManager", metadata: [
                        "name": volumeName,
                        "path": url.path,
                        "uuid": volumeUUID
                    ])
                }
                
                return Volume(
                    name: volumeName,
                    devicePath: url.path,
                    volumeUUID: volumeUUID
                )
            } catch {
                Task {
                    await logManager.error("Error getting resource values for volume", category: "VolumeManager", metadata: ["path": url.path, "error": error.localizedDescription])
                }
                return nil
            }
        }
        
        Task {
            await logManager.debug("loadVolumes completed", category: "VolumeManager", metadata: ["count": "\(volumes.count)"])
        }
        return volumes
    }
    
    /// Ejects the specified volume.
    /// - Parameter volume: The `Volume` to eject.
    /// - Throws: An error if the ejection fails.
    func ejectVolume(_ volume: Volume) {
        Task {
            await logManager.debug("Attempting to eject volume", category: "VolumeManager", metadata: ["name": volume.name, "path": volume.devicePath])
        }
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            Task {
                await logManager.debug("Successfully ejected volume", category: "VolumeManager", metadata: ["name": volume.name])
            }
        } catch {
            Task {
                await logManager.error("Error ejecting volume", category: "VolumeManager", metadata: ["path": volume.devicePath, "error": error.localizedDescription])
            }
        }
    }
} 