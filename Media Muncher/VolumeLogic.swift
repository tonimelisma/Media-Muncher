import SwiftUI

class VolumeLogic {
    static func loadVolumes(_ appState: AppState) {
        print("VolumeLogic: Loading volumes")
        appState.volumes = VolumeService.loadVolumes()
        print("VolumeLogic: Loaded \(appState.volumes.count) volumes")
        if appState.selectedVolumeID == nil, let firstVolume = appState.volumes.first {
            print("VolumeLogic: Selecting first volume")
            selectVolume(withID: firstVolume.id, appState: appState)
        }
    }
    
    static func selectVolume(withID id: String, appState: AppState) {
        print("VolumeLogic: Selecting volume with ID: \(id)")
        appState.selectedVolumeID = id
        if let volume = appState.volumes.first(where: { $0.id == id }) {
            if VolumeService.accessVolumeAndCreateBookmark(for: volume.devicePath) {
                print("VolumeLogic: Access granted, loading files")
                loadFilesForVolume(withID: id, appState: appState)
            } else {
                print("VolumeLogic: Access not granted")
                appState.fileItems = []
            }
        } else {
            print("VolumeLogic: No volume found with ID: \(id)")
        }
    }
    
    static func loadFilesForVolume(withID id: String, appState: AppState) {
        guard let volume = appState.volumes.first(where: { $0.id == id }) else {
            print("VolumeLogic: No volume found with ID: \(id) for loading files")
            appState.fileItems = []
            return
        }
        
        print("VolumeLogic: Loading files for volume: \(volume.name)")
        appState.fileItems = FileEnumerator.enumerateFiles(for: volume.devicePath)
        print("VolumeLogic: Loaded \(appState.fileItems.count) files")
    }
    
    static func ejectVolume(_ volume: Volume, appState: AppState) throws {
        print("VolumeLogic: Ejecting volume: \(volume.name)")
        try VolumeService.ejectVolume(volume)
        loadVolumes(appState)
    }
    
    static func refreshVolumes(_ appState: AppState) {
        print("VolumeLogic: Refreshing volumes")
        let oldSelectedID = appState.selectedVolumeID
        loadVolumes(appState)
        
        if let oldSelectedID = oldSelectedID,
           appState.volumes.contains(where: { $0.id == oldSelectedID }) {
            print("VolumeLogic: Re-selecting previously selected volume")
            selectVolume(withID: oldSelectedID, appState: appState)
        }
    }
}
