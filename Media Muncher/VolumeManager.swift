import SwiftUI

class VolumeManager: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolumeID: String?

    func loadVolumes() {
        print("VolumeManager: Loading volumes")
        let fileManager = FileManager.default
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) else {
            print("VolumeManager: Failed to get mounted volume URLs")
            return
        }

        volumes = mountedVolumeURLs.compactMap { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRemovableKey, .volumeUUIDStringKey])
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
        
        print("VolumeManager: Found \(volumes.count) removable volumes")
        
        if let selectedID = selectedVolumeID,
           !volumes.contains(where: { $0.id == selectedID }) {
            print("VolumeManager: Previously selected volume no longer available")
            selectedVolumeID = volumes.first?.id
        } else if selectedVolumeID == nil && !volumes.isEmpty {
            print("VolumeManager: No volume selected, selecting first available volume")
            selectedVolumeID = volumes.first?.id
        }
    }

    func selectVolume(withID id: String) {
        print("VolumeManager: Selecting volume with ID: \(id)")
        selectedVolumeID = id
        
        // Request access to the volume
        guard let volumeURL = URL(string: id) else {
            print("VolumeManager: Invalid volume URL")
            return
        }
        
        if volumeURL.startAccessingSecurityScopedResource() {
            print("VolumeManager: Successfully accessed volume at \(id)")
            // Remember to call stopAccessingSecurityScopedResource() when done
            // This should be called in a defer block or when you're done accessing the volume
        } else {
            print("VolumeManager: Failed to access volume at \(id)")
        }
    }
}
