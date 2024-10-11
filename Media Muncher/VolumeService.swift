import Foundation
import AppKit

/// `VolumeService` provides methods for interacting with storage volumes.
class VolumeService {
    /// Loads all removable volumes connected to the system.
    /// - Returns: An array of `Volume` objects representing the removable volumes.
    static func loadVolumes() -> [Volume] {
        print("VolumeService: Loading volumes")
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRemovableKey, .volumeUUIDStringKey]
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            print("VolumeService: Failed to get mounted volume URLs")
            return []
        }

        return mountedVolumeURLs.compactMap { url -> Volume? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                guard resourceValues.volumeIsRemovable == true else { return nil }
                print("VolumeService: Found removable volume: \(resourceValues.volumeName ?? "Unnamed Volume") at \(url.path)")
                return Volume(
                    id: url.path,
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    totalSize: Int64(resourceValues.volumeTotalCapacity ?? 0),
                    freeSize: Int64(resourceValues.volumeAvailableCapacity ?? 0),
                    volumeUUID: resourceValues.volumeUUIDString ?? "",
                    mediaFiles: [] // Initialize with an empty array of media files
                )
            } catch {
                print("VolumeService: Error getting resource values for volume at \(url): \(error)")
                return nil
            }
        }
    }
    
    /// Ejects the specified volume.
    /// - Parameter volume: The `Volume` to eject.
    /// - Throws: An error if the ejection fails.
    static func ejectVolume(_ volume: Volume) throws {
        print("VolumeService: Attempting to eject volume: \(volume.name)")
        let url = URL(fileURLWithPath: volume.devicePath)
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
        print("VolumeService: Successfully ejected volume: \(volume.name)")
    }
    
    /// Attempts to access a volume and create a security-scoped bookmark.
    /// - Parameters:
    ///   - path: The path of the volume to access.
    ///   - completion: A closure to be called with the result of the access attempt.
    static func accessVolumeAndCreateBookmark(for path: String, completion: @escaping (Bool) -> Void) {
        print("VolumeService: Attempting to access volume and create bookmark for \(path)")
        let url = URL(fileURLWithPath: path)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if url.startAccessingSecurityScopedResource() {
                    let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmark, forKey: "bookmark_\(path)")
                    print("VolumeService: Successfully accessed volume and created bookmark for \(path)")
                    url.stopAccessingSecurityScopedResource()
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    print("VolumeService: Failed to access volume for \(path)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } catch {
                print("VolumeService: Error accessing volume or creating bookmark: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Resolves a security-scoped bookmark for a volume.
    /// - Parameter path: The path of the volume to resolve.
    /// - Returns: `true` if the bookmark was successfully resolved and the volume accessed, `false` otherwise.
    static func resolveBookmark(for path: String) -> Bool {
        print("VolumeService: Attempting to resolve bookmark for \(path)")
        guard let bookmarkData = UserDefaults.standard.data(forKey: "bookmark_\(path)") else {
            print("VolumeService: No bookmark found for \(path)")
            return false
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("VolumeService: Bookmark for \(path) is stale")
                return false
            }
            
            if url.startAccessingSecurityScopedResource() {
                print("VolumeService: Successfully resolved bookmark and accessed volume for \(path)")
                return true
            } else {
                print("VolumeService: Failed to access volume after resolving bookmark for \(path)")
                return false
            }
        } catch {
            print("VolumeService: Error resolving bookmark for \(path): \(error)")
            return false
        }
    }
    
    // MARK: - Unused Functions (Kept as requested)
    
    /// Observes volume mount and unmount events.
    /// - Parameter callback: A closure to be called when a volume is mounted or unmounted.
    /// - Returns: A tuple of `NSObjectProtocol` objects representing the mount and unmount observers.
    static func observeVolumeChanges(callback: @escaping () -> Void) -> (NSObjectProtocol, NSObjectProtocol) {
        let notificationCenter = NotificationCenter.default

        let mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: nil
        ) { _ in
            print("VolumeService: Volume mounted notification received")
            callback()
        }

        let unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: nil
        ) { _ in
            print("VolumeService: Volume unmounted notification received")
            callback()
        }
        
        return (mountObserver, unmountObserver)
    }
    
    /// Removes the volume mount and unmount observers.
    /// - Parameter observers: A tuple of `NSObjectProtocol` objects representing the mount and unmount observers.
    static func removeVolumeObservers(_ observers: (NSObjectProtocol, NSObjectProtocol)) {
        NotificationCenter.default.removeObserver(observers.0)
        NotificationCenter.default.removeObserver(observers.1)
    }
}
