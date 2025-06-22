import Foundation
import SwiftUI

class VolumeManager: ObservableObject {
    @Published var volumes: [Volume] = []
    
    private var workspace: NSWorkspace = NSWorkspace.shared
    private var observers: [NSObjectProtocol] = []

    init() {
        self.volumes = loadVolumes()
        setupVolumeObservers()
    }

    deinit {
        removeVolumeObservers()
    }
    
    /// Sets up observers for volume mount and unmount events.
    private func setupVolumeObservers() {
        let mountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Volume mounted")
            guard let userInfo = notification.userInfo,
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("Couldn't get volume URL from mounting notification")
                return
            }
            print("Mounted volume URL: \(volumeURL.path)")

            guard
                let resources = try? volumeURL.resourceValues(forKeys: [
                    .volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey,
                ]),
                let uuid = resources.volumeUUIDString,
                let volumeName = userInfo[
                    NSWorkspace.localizedVolumeNameUserInfoKey] as? String
            else {
                print(
                    "Couldn't get UUID, localized name and other resources from mounting notification"
                )
                return
            }

            guard resources.volumeIsRemovable == true else {
                print("Not a removable volume, skipping")
                return
            }

            let newVolume: Volume = Volume(
                name: volumeName, devicePath: volumeURL.path,
                volumeUUID: uuid)

            self?.volumes.append(newVolume)
        }

        let unmountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Volume unmounted")
            guard let userInfo = notification.userInfo else {
                print("Couldn't get userInfo from unmounting notification")
                return
            }

            guard
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("Couldn't get volume URL from unmounting notification")
                return
            }
            print("Unmounted volume URL: \(volumeURL.path)")

            self?.volumes.removeAll { $0.devicePath == volumeURL.path }
        }

        self.observers.append(mountObserver)
        self.observers.append(unmountObserver)
        print("VolumeViewModel: Volume observers set up")
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        self.observers.forEach {
            workspace.notificationCenter.removeObserver($0)
        }
        self.observers.removeAll()
        print("VolumeViewModel: Volume observers removed")
    }

    /// Loads all removable volumes connected to the system.
    /// - Returns: An array of `Volume` objects representing the removable volumes.
    func loadVolumes() -> [Volume] {
        print("loadVolumes: Loading volumes")
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
            print("loadVolumes: Failed to get mounted volume URLs")
            return []
        }

        return mountedVolumeURLs.compactMap { url -> Volume? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                guard resourceValues.volumeIsRemovable == true else {
                    return nil
                }
                print(
                    "loadVolumes: Found removable volume: \(resourceValues.volumeName ?? "Unnamed Volume") at \(url.path)"
                )
                return Volume(
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print(
                    "Error getting resource values for volume at \(url): \(error)"
                )
                return nil
            }
        }
    }
    
    /// Ejects the specified volume.
    /// - Parameter volume: The `Volume` to eject.
    /// - Throws: An error if the ejection fails.
    func ejectVolume(_ volume: Volume) {
        print("Attempting to eject volume: \(volume.name)")
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            print("Successfully ejected volume: \(volume.name)")
        } catch {
            print("Error ejecting volume \(volume.devicePath): \(error)")
        }
    }
} 