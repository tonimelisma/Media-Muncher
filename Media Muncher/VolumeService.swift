import Foundation
import AppKit

class VolumeService {
    private static var volumeBookmarks: [String: Data] = [:]
    
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
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print("VolumeService: Error getting resource values for volume at \(url): \(error)")
                return nil
            }
        }
    }
    
    static func ejectVolume(_ volume: Volume) throws {
        print("VolumeService: Attempting to eject volume: \(volume.name)")
        let url = URL(fileURLWithPath: volume.devicePath)
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
        print("VolumeService: Successfully ejected volume: \(volume.name)")
    }
    
    static func createAndStoreBookmark(for path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            volumeBookmarks[path] = bookmark
            if url.startAccessingSecurityScopedResource() {
                print("VolumeService: Successfully created bookmark and accessed volume")
                return true
            } else {
                print("VolumeService: Created bookmark but failed to access volume")
                return false
            }
        } catch {
            print("VolumeService: Error creating bookmark: \(error)")
            return false
        }
    }
    
    static func getBookmark(for path: String) -> Data? {
        return volumeBookmarks[path]
    }
    
    static func resolveBookmark(_ bookmark: Data, for path: String) -> Bool {
        var isStale = false
        do {
            let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                print("VolumeService: Bookmark is stale, creating new one")
                return createAndStoreBookmark(for: path)
            } else if resolvedURL.startAccessingSecurityScopedResource() {
                print("VolumeService: Successfully accessed volume using bookmark")
                return true
            }
        } catch {
            print("VolumeService: Error resolving bookmark: \(error)")
        }
        return false
    }
    
    static func stopAccessingVolume(withID id: String) {
        let url = URL(fileURLWithPath: id)
        url.stopAccessingSecurityScopedResource()
    }
    
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
    
    static func removeVolumeObservers(_ observers: (NSObjectProtocol, NSObjectProtocol)) {
        NotificationCenter.default.removeObserver(observers.0)
        NotificationCenter.default.removeObserver(observers.1)
    }
}
