import SwiftUI

class VolumeViewModel: ObservableObject {
    @Published var volumes: [Volume] = []
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    
    init() {
        setupVolumeObserver()
        loadVolumes()
    }
    
    deinit {
        if let observer = mountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = unmountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func loadVolumes() {
        print("loadVolumes() called")
        let fileManager = FileManager.default
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) else {
            print("Failed to get mounted volume URLs")
            return
        }

        volumes = mountedVolumeURLs.compactMap { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsRemovableKey, .volumeUUIDStringKey])
                guard resourceValues.volumeIsRemovable == true else { return nil }
                return Volume(
                    id: url.path,
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    totalSize: Int64(resourceValues.volumeTotalCapacity ?? 0),
                    freeSize: Int64(resourceValues.volumeAvailableCapacity ?? 0),
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print("Error getting resource values for volume at \(url): \(error)")
                return nil
            }
        }
    }
    
    func ejectVolume(_ volume: Volume) {
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            self.loadVolumes()  // Reload volumes after ejection
        } catch {
            print("Error ejecting volume: \(error.localizedDescription)")
        }
    }
    
    private func setupVolumeObserver() {
        let notificationCenter = NotificationCenter.default

        mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.loadVolumes()
        }

        unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.loadVolumes()
        }
    }
}
