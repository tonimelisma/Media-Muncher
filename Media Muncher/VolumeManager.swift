import SwiftUI

class VolumeManager: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolumeID: String?
    private var volumeBookmarks: [String: Data] = [:]

    func loadVolumes() {
        print("VolumeManager: Loading volumes")
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRemovableKey, .volumeUUIDStringKey]
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            print("VolumeManager: Failed to get mounted volume URLs")
            return
        }

        let oldVolumeIDs = Set(self.volumes.map { $0.id })
        let newVolumes: [Volume] = mountedVolumeURLs.compactMap { url -> Volume? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                guard resourceValues.volumeIsRemovable == true else { return nil }
                print("VolumeManager: Found removable volume: \(resourceValues.volumeName ?? "Unnamed Volume") at \(url.path)")
                return Volume(
                    id: url.path,
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    totalSize: Int64(resourceValues.volumeTotalCapacity ?? 0),
                    freeSize: Int64(resourceValues.volumeAvailableCapacity ?? 0),
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print("VolumeManager: Error getting resource values for volume at \(url): \(error)")
                return nil
            }
        }
        
        let newVolumeIDs = Set(newVolumes.map { $0.id })
        
        print("VolumeManager: Found \(newVolumes.count) removable volumes")
        
        // Check if the volume list has changed
        let volumesChanged = oldVolumeIDs != newVolumeIDs
        
        self.volumes = newVolumes
        
        // If the previously selected volume is no longer available, clear the selection
        if let selectedID = selectedVolumeID,
           !newVolumeIDs.contains(selectedID) {
            print("VolumeManager: Previously selected volume no longer available")
            selectedVolumeID = nil
        }
        
        // If no volume is selected, select the first one
        if selectedVolumeID == nil && !newVolumes.isEmpty {
            print("VolumeManager: No volume selected, selecting first available volume")
            selectVolume(withID: newVolumes[0].id)
        }
        
        if volumesChanged {
            print("VolumeManager: Volumes list changed")
            objectWillChange.send()
        } else {
            print("VolumeManager: Volumes list remained the same")
        }
    }

    func selectVolume(withID id: String) {
        print("VolumeManager: Selecting volume with ID: \(id)")
        
        // Only update if it's a new selection
        guard id != selectedVolumeID else {
            print("VolumeManager: Volume already selected, no change needed")
            return
        }
        
        selectedVolumeID = id
        
        let volumeURL = URL(fileURLWithPath: id)
        
        if let bookmark = volumeBookmarks[id] {
            var isStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    print("VolumeManager: Bookmark is stale, creating new one")
                    createBookmark(for: volumeURL.path)
                } else if resolvedURL.startAccessingSecurityScopedResource() {
                    print("VolumeManager: Successfully accessed volume using bookmark")
                    return
                }
            } catch {
                print("VolumeManager: Error resolving bookmark: \(error)")
            }
        }
        
        // If we don't have a valid bookmark, try to create one
        createBookmark(for: volumeURL.path)
    }
    
    private func createBookmark(for path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            volumeBookmarks[path] = bookmark
            if url.startAccessingSecurityScopedResource() {
                print("VolumeManager: Successfully created bookmark and accessed volume")
            } else {
                print("VolumeManager: Created bookmark but failed to access volume")
            }
        } catch {
            print("VolumeManager: Error creating bookmark: \(error)")
        }
    }
    
    func stopAccessingVolume(withID id: String) {
        let url = URL(fileURLWithPath: id)
        url.stopAccessingSecurityScopedResource()
    }
}
