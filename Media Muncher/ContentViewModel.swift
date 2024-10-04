import SwiftUI
import Combine

class ContentViewModel: ObservableObject {
    @Published var fileItems: [FileItem] = []
    @Published var selectedVolumeID: String?
    
    private let volumeManager: VolumeManager
    private let volumeObserver: VolumeObserver
    private var cancellables = Set<AnyCancellable>()
    
    var volumes: [Volume] { volumeManager.volumes }

    init() {
        print("ContentViewModel: Initializing")
        self.volumeManager = VolumeManager()
        self.volumeObserver = VolumeObserver(onVolumeChange: {})
        self.setupVolumeObserver()
        self.setupVolumeManagerBindings()
        self.volumeManager.loadVolumes()
    }

    private func setupVolumeObserver() {
        volumeObserver.onVolumeChange = { [weak self] in
            print("ContentViewModel: Volume change detected")
            self?.refreshVolumes()
        }
    }

    private func setupVolumeManagerBindings() {
        volumeManager.$selectedVolumeID
            .sink { [weak self] newID in
                print("ContentViewModel: Selected volume ID changed to: \(newID ?? "nil")")
                self?.selectedVolumeID = newID
                if let id = newID {
                    self?.selectVolume(withID: id)
                } else {
                    self?.clearFileItems()
                }
            }
            .store(in: &cancellables)
    }

    func refreshVolumes() {
        print("ContentViewModel: Refreshing volumes")
        volumeManager.loadVolumes()
    }

    func selectVolume(withID id: String) {
        print("ContentViewModel: Selecting volume with ID: \(id)")
        if let selectedVolume = volumes.first(where: { $0.id == id }) {
            print("ContentViewModel: Enumerating files for volume: \(selectedVolume.name)")
            enumerateFiles(for: selectedVolume.devicePath)
        } else {
            print("ContentViewModel: Selected volume not found, clearing file items")
            clearFileItems()
        }
    }

    func enumerateFiles(for volumePath: String) {
        print("ContentViewModel: Attempting to enumerate files at path: \(volumePath)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = FileEnumerator.enumerateFiles(for: volumePath)
            DispatchQueue.main.async {
                self?.fileItems = items
                print("ContentViewModel: Final fileItems count: \(items.count)")
            }
        }
    }

    func clearFileItems() {
        print("ContentViewModel: Clearing file items")
        fileItems.removeAll()
    }
}
