import SwiftUI

class ContentViewModel: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var selectedVolumeID: String?
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?

    init() {
        setupVolumeObserver()
        loadVolumes()
    }

    deinit {
        tearDownVolumeObserver()
    }

    func loadVolumes() {
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
        
        if selectedVolumeID == nil, let firstVolume = volumes.first {
            selectedVolumeID = firstVolume.id
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

    private func tearDownVolumeObserver() {
        if let observer = mountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = unmountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
