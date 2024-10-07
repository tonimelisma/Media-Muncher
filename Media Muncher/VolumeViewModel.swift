import SwiftUI

class VolumeViewModel: ObservableObject {
    @Published var appState: AppState
    private var observers: [NSObjectProtocol] = []

    init(appState: AppState) {
        self.appState = appState
        setupVolumeObservers()
    }

    deinit {
        removeVolumeObservers()
    }

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

    private func removeVolumeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    func loadVolumes() {
        print("VolumeViewModel: Loading volumes")
        appState.volumes = VolumeService.loadVolumes()
        print("VolumeViewModel: Loaded \(appState.volumes.count) volumes")
        ensureVolumeSelection()
    }
    
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
    
    func ejectVolume(_ volume: Volume) throws {
        print("VolumeViewModel: Ejecting volume: \(volume.name)")
        try VolumeService.ejectVolume(volume)
        refreshVolumes()
    }
    
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
