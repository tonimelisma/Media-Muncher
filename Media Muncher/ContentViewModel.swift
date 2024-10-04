import SwiftUI
import Combine
import AppKit

class ContentViewModel: ObservableObject {
    @Published var fileItems: [FileItem] = []
    @Published var errorMessage: String?
    @Published var showingPermissionAlert = false
    
    private let volumeManager: VolumeManager
    private let volumeObserver: VolumeObserver
    private var cancellables = Set<AnyCancellable>()
    
    var volumes: [Volume] { volumeManager.volumes }
    var selectedVolumeID: String? { volumeManager.selectedVolumeID }

    init(volumeManager: VolumeManager) {
        print("ContentViewModel: Initializing")
        self.volumeManager = volumeManager
        self.volumeObserver = VolumeObserver(onVolumeChange: {})
        self.setupVolumeObserver()
        self.setupBindings()
        self.volumeManager.loadVolumes()
    }

    private func setupVolumeObserver() {
        volumeObserver.onVolumeChange = { [weak self] in
            print("ContentViewModel: Volume change detected")
            self?.refreshVolumes()
        }
    }

    private func setupBindings() {
        volumeManager.$selectedVolumeID
            .sink { [weak self] newID in
                print("ContentViewModel: Selected volume ID changed to: \(newID ?? "nil")")
                if let id = newID {
                    self?.loadFilesForVolume(withID: id)
                } else {
                    self?.clearFileItems()
                }
            }
            .store(in: &cancellables)
        
        volumeManager.$volumes
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func refreshVolumes() {
        print("ContentViewModel: Refreshing volumes")
        let oldSelectedID = volumeManager.selectedVolumeID
        volumeManager.loadVolumes()
        
        // If the selected volume is still available, maintain the selection
        if let oldSelectedID = oldSelectedID,
           volumeManager.volumes.contains(where: { $0.id == oldSelectedID }) {
            volumeManager.selectVolume(withID: oldSelectedID)
        }
    }

    func selectVolume(withID id: String) {
        print("ContentViewModel: Selecting volume with ID: \(id)")
        volumeManager.selectVolume(withID: id)
    }

    func loadFilesForVolume(withID id: String) {
        print("ContentViewModel: Loading files for volume with ID: \(id)")
        guard let selectedVolume = volumes.first(where: { $0.id == id }) else {
            print("ContentViewModel: Selected volume not found, clearing file items")
            clearFileItems()
            return
        }
        print("ContentViewModel: Enumerating files for volume: \(selectedVolume.name)")
        enumerateFiles(for: selectedVolume.devicePath)
    }

    func enumerateFiles(for volumePath: String) {
        print("ContentViewModel: Attempting to enumerate files at path: \(volumePath)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = FileEnumerator.enumerateFiles(for: volumePath)
            DispatchQueue.main.async {
                if items.isEmpty {
                    self?.errorMessage = "Unable to access the volume. Click here for more information."
                    self?.showingPermissionAlert = true
                } else {
                    self?.errorMessage = nil
                }
                self?.fileItems = items
                print("ContentViewModel: Final fileItems count: \(items.count)")
            }
        }
    }

    func requestVolumeAccess() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Please select the volume you want to access"
        openPanel.prompt = "Select Volume"

        if let url = URL(string: selectedVolumeID ?? "") {
            openPanel.directoryURL = url
        }

        openPanel.begin { [weak self] result in
            if result == .OK {
                if let url = openPanel.url {
                    self?.selectVolume(withID: url.path)
                }
            }
        }
    }

    func clearFileItems() {
        print("ContentViewModel: Clearing file items")
        fileItems.removeAll()
        errorMessage = nil
    }
    
    deinit {
        if let id = selectedVolumeID {
            volumeManager.stopAccessingVolume(withID: id)
        }
    }
}
