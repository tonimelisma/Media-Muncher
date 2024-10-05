import SwiftUI

class VolumeLogic {
    static func loadVolumes(_ appState: AppState) {
        print("VolumeLogic: Loading volumes")
        appState.volumes = VolumeService.loadVolumes()
        print("VolumeLogic: Loaded \(appState.volumes.count) volumes")
        for volume in appState.volumes {
            checkVolumePermission(volume, appState: appState)
        }
        if appState.selectedVolumeID == nil, let firstVolume = appState.volumes.first {
            print("VolumeLogic: Selecting first volume")
            selectVolume(withID: firstVolume.id, appState: appState)
        }
    }
    
    static func selectVolume(withID id: String, appState: AppState) {
        appState.selectedVolumeID = id
        loadFilesForVolume(withID: id, appState: appState)
    }
    
    static func loadFilesForVolume(withID id: String, appState: AppState) {
        guard let volume = appState.volumes.first(where: { $0.id == id }) else {
            appState.fileItems = []
            return
        }
        
        if appState.volumePermissions[id] == true {
            appState.fileItems = FileEnumerator.enumerateFiles(for: volume.devicePath)
        } else {
            appState.errorMessage = "Permission required to access this volume."
            appState.showingPermissionAlert = true
        }
    }
    
    static func ejectVolume(_ volume: Volume, appState: AppState) {
        do {
            try VolumeService.ejectVolume(volume)
            loadVolumes(appState)
        } catch {
            appState.errorMessage = "Failed to eject volume: \(error.localizedDescription)"
        }
    }
    
    static func refreshVolumes(_ appState: AppState) {
        let oldSelectedID = appState.selectedVolumeID
        loadVolumes(appState)
        
        if let oldSelectedID = oldSelectedID,
           appState.volumes.contains(where: { $0.id == oldSelectedID }) {
            selectVolume(withID: oldSelectedID, appState: appState)
        }
    }
    
    static func requestVolumeAccess(_ appState: AppState) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Please select the volume you want to access"
        openPanel.prompt = "Select Volume"

        if let url = URL(string: appState.selectedVolumeID ?? "") {
            openPanel.directoryURL = url
        }

        openPanel.begin { result in
            if result == .OK {
                if let url = openPanel.url {
                    if VolumeService.createAndStoreBookmark(for: url.path) {
                        appState.volumePermissions[url.path] = true
                        selectVolume(withID: url.path, appState: appState)
                    } else {
                        appState.errorMessage = "Failed to create bookmark for the selected volume."
                        appState.showingPermissionAlert = true
                    }
                }
            }
        }
    }
    
    private static func checkVolumePermission(_ volume: Volume, appState: AppState) {
        if let bookmark = VolumeService.getBookmark(for: volume.id) {
            let hasPermission = VolumeService.resolveBookmark(bookmark, for: volume.id)
            appState.volumePermissions[volume.id] = hasPermission
        } else {
            appState.volumePermissions[volume.id] = false
        }
    }
}
