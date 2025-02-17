//
//  AppState.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/15/25.
//
import SwiftUI

class AppState: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolume: String? = nil

    private var workspace: NSWorkspace = NSWorkspace.shared
    private var observers: [NSObjectProtocol] = []

    init() {
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
            guard let userInfo = notification.userInfo else {
                print("Couldn't get userInfo from mounting notification")
                return
            }

            guard
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("Couldn't get volume URL from mounting notification")
                return
            }
            print("Mounted volume URL: \(volumeURL.path)")

            guard
                let resources = try? volumeURL.resourceValues(forKeys: [
                    .volumeUUIDStringKey, .nameKey,
                ]),
                let uuid = resources.volumeUUIDString
            else {
                print("Couldn't get UUID from mounting notification")
                return
            }
            print("UUID is \(uuid)")

            guard
                let volumeName = userInfo[
                    NSWorkspace.localizedVolumeNameUserInfoKey] as? String
            else {
                print("Couldn't get volume name from mounting notification")
                return
            }
            print("Mounted volume name: \(volumeName)")

            let newVolume: Volume = Volume(
                name: volumeName, devicePath: volumeURL.path,
                volumeUUID: uuid)

            self?.volumes.append(newVolume)
            if self?.volumes.count == 1 {
                print("First volume mounted, choosing it")
                self?.ensureVolumeSelection()
            }
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

            if self?.selectedVolume == volumeURL.path {
                print("Selected volume was unmounted, making a new selection")
                self?.ensureVolumeSelection()
            }
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

    /// This function is called when the app is started or the selected volume was unmounted and we need to select a new volume
    /// Select the first available one, or nil if none are available
    func ensureVolumeSelection() {
        if let firstVolume = self.volumes.first {
            print("VolumeViewModel: Selecting first available volume")
            self.selectedVolume = firstVolume.devicePath
        } else {
            print("VolumeViewModel: No volumes available to select")
            self.selectedVolume = nil
        }
    }

    /// Selects a volume with the given ID.
    /// - Parameter id: The ID of the volume to select.
    func selectVolume(_ id: String?) {
        print("VolumeViewModel: Selecting volume with ID: \(id ?? "nil")")
        DispatchQueue.main.async {
            self.selectedVolume = id
        }
        // guard let id = id else {
        //     return
        // }

        // if let volumeIndex = self.volumes.firstIndex(where: { $0.id == id }) {
        // if self.selectedVolume != id {
        // self.selectedVolume = id
        // self.isSelectedVolumeAccessible = false
        // self.mediaFiles = []
        // }

        // VolumeService.accessVolumeAndCreateBookmark(
        //     for: appState.volumes[volumeIndex].devicePath
        // ) { [weak self] success in
        //     self?.handleVolumeAccess(for: id, granted: success)
        // }
        // } else {
        // print("VolumeViewModel: No volume found with ID: \(id)")
        // self.selectedVolume = nil
        // appState.isSelectedVolumeAccessible = false
        // }
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
