import Foundation

class VolumesViewModel: ObservableObject {
    @Published var volumes: [Volume] = []

    func loadVolumes() {
        let fileManager = FileManager.default
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) else {
            return
        }

        volumes = mountedVolumeURLs.compactMap { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeUUIDStringKey
                ])
                
                return Volume(
                    id: url.path,
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    totalSize: Int64(resourceValues.volumeTotalCapacity ?? 0),
                    freeSize: Int64(resourceValues.volumeAvailableCapacity ?? 0),
                    isRemovable: resourceValues.volumeIsRemovable ?? false,
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print("Error getting resource values for volume at \(url): \(error)")
                return nil
            }
        }
    }
}

struct Volume: Identifiable {
    let id: String
    let name: String
    let devicePath: String
    let totalSize: Int64
    let freeSize: Int64
    let isRemovable: Bool
    let volumeUUID: String
    
    var usedSize: Int64 {
        return totalSize - freeSize
    }
}
