import SwiftUI

/// `VolumeViewModel` manages the state and logic for volumes in the application.
class VolumeViewModel: ObservableObject {
    @Published var appState: AppState
    private var observers: [NSObjectProtocol] = []

    /// Initializes the VolumeViewModel with the given AppState.
    /// - Parameter appState: The global app state.
    init(appState: AppState) {
        self.appState = appState
        setupVolumeObservers()
        print("VolumeViewModel: Initialized")
    }

    deinit {
        removeVolumeObservers()
    }

    /// Sets up observers for volume mount and unmount events.
    private func setupVolumeObservers() {
        let notificationCenter = NotificationCenter.default

        let mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            print("VolumeViewModel: Volume mounted")
            self?.refreshVolumes()
        }

        let unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            print("VolumeViewModel: Volume unmounted")
            self?.refreshVolumes()
        }

        observers.append(mountObserver)
        observers.append(unmountObserver)
        print("VolumeViewModel: Volume observers set up")
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        print("VolumeViewModel: Volume observers removed")
    }

    /// Loads available volumes.
    func loadVolumes() {
        print("VolumeViewModel: Loading volumes")
        appState.volumes = VolumeService.loadVolumes()
        print("VolumeViewModel: Loaded \(appState.volumes.count) volumes")
        ensureVolumeSelection()
    }
    
    /// Ensures that a volume is selected if available.
    func ensureVolumeSelection() {
        print("VolumeViewModel: Ensuring volume selection")
        if let selectedID = appState.selectedVolumeID,
           appState.volumes.contains(where: { $0.id == selectedID }) {
            print("VolumeViewModel: Previously selected volume still exists")
            return
        }
        
        if let firstVolume = appState.volumes.first {
            print("VolumeViewModel: Selecting first available volume")
            selectVolume(withID: firstVolume.id)
        } else {
            print("VolumeViewModel: No volumes available to select")
            appState.selectedVolumeID = nil
        }
    }
    
    /// Selects a volume with the given ID.
    /// - Parameter id: The ID of the volume to select.
    func selectVolume(withID id: String) {
        print("VolumeViewModel: Selecting volume with ID: \(id)")
        if let volumeIndex = appState.volumes.firstIndex(where: { $0.id == id }) {
            if VolumeService.accessVolumeAndCreateBookmark(for: appState.volumes[volumeIndex].devicePath) {
                print("VolumeViewModel: Access granted, enumerating file system")
                let mediaFiles = FileEnumerator.enumerateFileSystem(for: appState.volumes[volumeIndex].devicePath)
                appState.volumes[volumeIndex].mediaFiles = mediaFiles
                print("VolumeViewModel: Media files set for volume: \(appState.volumes[volumeIndex].name)")
                print("VolumeViewModel: Media files count: \(mediaFiles.count)")
                
                // Update selectedVolumeID after setting mediaFiles
                appState.selectedVolumeID = id
            } else {
                print("VolumeViewModel: Access not granted")
                appState.volumes[volumeIndex].mediaFiles = []
                appState.selectedVolumeID = nil
            }
        } else {
            print("VolumeViewModel: No volume found with ID: \(id)")
            appState.selectedVolumeID = nil
        }
    }
    
    /// Ejects the specified volume.
    /// - Parameter volume: The volume to eject.
    /// - Throws: An error if the ejection fails.
    func ejectVolume(_ volume: Volume) throws {
        print("VolumeViewModel: Ejecting volume: \(volume.name)")
        try VolumeService.ejectVolume(volume)
        refreshVolumes()
    }
    
    /// Refreshes the list of available volumes.
    func refreshVolumes() {
        print("VolumeViewModel: Refreshing volumes")
        let oldSelectedID = appState.selectedVolumeID
        loadVolumes()
        
        if let oldSelectedID = oldSelectedID,
           appState.volumes.contains(where: { $0.id == oldSelectedID }) {
            print("VolumeViewModel: Re-selecting previously selected volume")
            selectVolume(withID: oldSelectedID)
        } else {
            ensureVolumeSelection()
        }
    }
}
