import AppKit
import Combine
import Foundation

class VolumesViewModel: ObservableObject {
    @Published var removableVolumes: [Volume] = []
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?

    init() {
        print("VolumesViewModel initialized")
        setupVolumeObserver()
        loadVolumes()
    }

    deinit {
        print("VolumesViewModel is being deinitialized")
        if let observer = mountObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            print("Mount observer removed")
        }
        if let observer2 = unmountObserver {
            DistributedNotificationCenter.default().removeObserver(observer2)
            print("Unmount observer removed")
        }
    }

    func loadVolumes() {
        print("loadVolumes() called")
        let fileManager = FileManager.default
        guard
            let mountedVolumeURLs = fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: nil,
                options: [.skipHiddenVolumes])
        else {
            print("Failed to get mounted volume URLs")
            return
        }

        removableVolumes = mountedVolumeURLs.compactMap { url in
            do {
                let resourceValues = try url.resourceValues(forKeys: [
                    .volumeNameKey,
                    .volumeTotalCapacityKey,
                    .volumeAvailableCapacityKey,
                    .volumeIsRemovableKey,
                    .volumeUUIDStringKey,
                ])

                guard resourceValues.volumeIsRemovable == true else {
                    return nil
                }

                let volume = Volume(
                    id: url.path,
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    totalSize: Int64(resourceValues.volumeTotalCapacity ?? 0),
                    freeSize: Int64(
                        resourceValues.volumeAvailableCapacity ?? 0),
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
                return volume
            } catch {
                print(
                    "Error getting resource values for volume at \(url): \(error)"
                )
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
        print("Setting up volume observer")
        let notificationCenter = NotificationCenter.default

        mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil,
            queue: nil
        ) { notification in
            print("Notification of a mounted volume received")
            self.loadVolumes()
        }

        unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil,
            queue: nil
        ) { notification in
            print("Notification of a volume unmount received")
            self.loadVolumes()
        }

        print(
            "Volume observer setup complete. mountObserver: \(mountObserver != nil ? "Success" : "Failed"), unmountObserver: \(unmountObserver != nil ? "Success" : "Failed")"
        )
    }
}
