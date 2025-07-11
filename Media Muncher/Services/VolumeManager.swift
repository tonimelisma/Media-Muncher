import Foundation
import SwiftUI

class VolumeManager: ObservableObject {
    @Published var volumes: [Volume] = []
    
    private var workspace: NSWorkspace = NSWorkspace.shared
    private var observers: [NSObjectProtocol] = []

    init() {
        print("[VolumeManager] DEBUG: Initializing VolumeManager")
        self.volumes = loadVolumes()
        print("[VolumeManager] DEBUG: Initial volumes loaded: \(volumes.count)")
        setupVolumeObservers()
    }

    deinit {
        print("[VolumeManager] DEBUG: Deinitializing VolumeManager")
        removeVolumeObservers()
    }
    
    /// Sets up observers for volume mount and unmount events.
    private func setupVolumeObservers() {
        print("[VolumeManager] DEBUG: Setting up volume observers")
        
        let mountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("[VolumeManager] DEBUG: Volume mounted notification received")
            print("[VolumeManager] DEBUG: Notification: \(notification)")
            
            guard let userInfo = notification.userInfo,
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("[VolumeManager] ERROR: Couldn't get volume URL from mounting notification")
                print("[VolumeManager] DEBUG: userInfo: \(notification.userInfo ?? [:])")
                return
            }
            print("[VolumeManager] DEBUG: Mounted volume URL: \(volumeURL.path)")

            guard
                let resources = try? volumeURL.resourceValues(forKeys: [
                    .volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey,
                ]),
                let uuid = resources.volumeUUIDString,
                let volumeName = userInfo[
                    NSWorkspace.localizedVolumeNameUserInfoKey] as? String
            else {
                print("[VolumeManager] ERROR: Couldn't get UUID, localized name and other resources from mounting notification")
                print("[VolumeManager] DEBUG: Available resources: \(String(describing: try? volumeURL.resourceValues(forKeys: [.volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey])))")
                return
            }

            print("[VolumeManager] DEBUG: Volume UUID: \(uuid)")
            print("[VolumeManager] DEBUG: Volume name: \(volumeName)")
            print("[VolumeManager] DEBUG: Volume is removable: \(resources.volumeIsRemovable == true)")

            guard resources.volumeIsRemovable == true else {
                print("[VolumeManager] DEBUG: Not a removable volume, skipping")
                return
            }

            let newVolume: Volume = Volume(
                name: volumeName, devicePath: volumeURL.path,
                volumeUUID: uuid)

            print("[VolumeManager] DEBUG: Adding new volume: \(newVolume)")
            self?.volumes.append(newVolume)
            print("[VolumeManager] DEBUG: Total volumes after addition: \(self?.volumes.count ?? 0)")
        }

        let unmountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("[VolumeManager] DEBUG: Volume unmounted notification received")
            print("[VolumeManager] DEBUG: Notification: \(notification)")
            
            guard let userInfo = notification.userInfo else {
                print("[VolumeManager] ERROR: Couldn't get userInfo from unmounting notification")
                return
            }

            guard
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("[VolumeManager] ERROR: Couldn't get volume URL from unmounting notification")
                print("[VolumeManager] DEBUG: userInfo: \(userInfo)")
                return
            }
            print("[VolumeManager] DEBUG: Unmounted volume URL: \(volumeURL.path)")

            let removedCount = self?.volumes.count ?? 0
            self?.volumes.removeAll { $0.devicePath == volumeURL.path }
            let remainingCount = self?.volumes.count ?? 0
            print("[VolumeManager] DEBUG: Removed volume, count before: \(removedCount), after: \(remainingCount)")
        }

        self.observers.append(mountObserver)
        self.observers.append(unmountObserver)
        print("[VolumeManager] DEBUG: Volume observers set up successfully")
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        print("[VolumeManager] DEBUG: Removing volume observers")
        self.observers.forEach {
            workspace.notificationCenter.removeObserver($0)
        }
        self.observers.removeAll()
        print("[VolumeManager] DEBUG: Volume observers removed")
    }

    /// Loads all removable volumes connected to the system.
    /// - Returns: An array of `Volume` objects representing the removable volumes.
    func loadVolumes() -> [Volume] {
        print("[VolumeManager] DEBUG: loadVolumes called")
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
            print("[VolumeManager] ERROR: Failed to get mounted volume URLs")
            return []
        }
        
        print("[VolumeManager] DEBUG: Found \(mountedVolumeURLs.count) mounted volumes")

        let volumes = mountedVolumeURLs.compactMap { url -> Volume? in
            print("[VolumeManager] DEBUG: Examining volume at: \(url.path)")
            
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                print("[VolumeManager] DEBUG: Resource values for \(url.path): \(resourceValues)")
                
                guard resourceValues.volumeIsRemovable == true else {
                    print("[VolumeManager] DEBUG: Volume \(url.path) is not removable, skipping")
                    return nil
                }
                
                let volumeName = resourceValues.volumeName ?? "Unnamed Volume"
                let volumeUUID = resourceValues.volumeUUIDString ?? ""
                
                print("[VolumeManager] DEBUG: Found removable volume: \(volumeName) at \(url.path) with UUID: \(volumeUUID)")
                
                return Volume(
                    name: volumeName,
                    devicePath: url.path,
                    volumeUUID: volumeUUID
                )
            } catch {
                print("[VolumeManager] ERROR: Error getting resource values for volume at \(url.path): \(error)")
                return nil
            }
        }
        
        print("[VolumeManager] DEBUG: loadVolumes returning \(volumes.count) removable volumes")
        return volumes
    }
    
    /// Ejects the specified volume.
    /// - Parameter volume: The `Volume` to eject.
    /// - Throws: An error if the ejection fails.
    func ejectVolume(_ volume: Volume) {
        print("[VolumeManager] DEBUG: Attempting to eject volume: \(volume.name) at \(volume.devicePath)")
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            print("[VolumeManager] DEBUG: Successfully ejected volume: \(volume.name)")
        } catch {
            print("[VolumeManager] ERROR: Error ejecting volume \(volume.devicePath): \(error)")
        }
    }
} 