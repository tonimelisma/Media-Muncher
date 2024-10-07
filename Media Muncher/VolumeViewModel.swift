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
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
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
        if let selectedID = appState.selectedVolumeID,
           appState.volumes.contains(where: { $0.id == selectedID }) {
            // The selected volume still exists, no need to change
            return
        }
        
        // Either no volume was selected or the selected volume no longer exists
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
        appState.selectedVolumeID = id
        if let volume = appState.volumes.first(where: { $0.id == id }) {
            if VolumeService.accessVolumeAndCreateBookmark(for: volume.devicePath) {
                print("VolumeViewModel: Access granted, loading files")
                // Note: We'll need to update MediaViewModel to load files
            } else {
                print("VolumeViewModel: Access not granted")
                // Note: We'll need to update MediaViewModel to clear files
            }
        } else {
            print("VolumeViewModel: No volume found with ID: \(id)")
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
