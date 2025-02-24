import AVFoundation
//
//  AppState.swift
//  Media Muncher
//
//  Created by Toni Melisma on 2/15/25.
//
import SwiftUI

enum programState {
    case idle
    case enumeratingFiles
}

enum errorState {
    case none
    case destinationFolderNotWritable
}

class AppState: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published private(set) var selectedVolume: String? = nil

    @Published var files: [File] = []

    @Published var state: programState = programState.idle
    @Published var error: errorState = errorState.none

    // Settings
    @Published var settingDeleteOriginals: Bool {
        didSet {
            UserDefaults.standard.set(settingDeleteOriginals, forKey: "settingDeleteOriginals")
        }
    }
    @Published var settingDeletePrevious: Bool {
        didSet {
            UserDefaults.standard.set(settingDeletePrevious, forKey: "settingDeletePrevious")
        }
    }
    @Published var settingDestinationFolder: String {
        didSet {
            UserDefaults.standard.set(settingDestinationFolder, forKey: "settingDestinationFolder")
        }
    }

    func setSettingDestinationFolder(_ folder: String) {
        settingDestinationFolder = folder
    }

    private var workspace: NSWorkspace = NSWorkspace.shared
    private var observers: [NSObjectProtocol] = []

    init() {
        self.settingDeleteOriginals = UserDefaults.standard.bool(forKey: "settingDeleteOriginals")
        self.settingDeletePrevious = UserDefaults.standard.bool(forKey: "settingDeletePrevious")
        self.settingDestinationFolder =
            UserDefaults.standard.string(forKey: "settingDestinationFolder") ?? FileManager.default.urls(
                for: .picturesDirectory, in: .userDomainMask
            ).first?.path ?? ""

        setupVolumeObservers()
    }

    deinit {
        removeVolumeObservers()
    }

    /// Sets up observers for volume mount and unmount events.
    private func setupVolumeObservers() {
        let mountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Volume mounted")
            guard let userInfo = notification.userInfo,
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("Couldn't get volume URL from mounting notification")
                return
            }
            print("Mounted volume URL: \(volumeURL.path)")

            guard
                let resources = try? volumeURL.resourceValues(forKeys: [
                    .volumeUUIDStringKey, .nameKey, .volumeIsRemovableKey,
                ]),
                let uuid = resources.volumeUUIDString,
                let volumeName = userInfo[
                    NSWorkspace.localizedVolumeNameUserInfoKey] as? String
            else {
                print(
                    "Couldn't get UUID, localized name and other resources from mounting notification"
                )
                return
            }

            guard resources.volumeIsRemovable == true else {
                print("Not a removable volume, skipping")
                return
            }

            let newVolume: Volume = Volume(
                name: volumeName, devicePath: volumeURL.path,
                volumeUUID: uuid)

            self?.volumes.append(newVolume)
            if self?.volumes.count == 1 {
                print("First volume mounted, choosing it")
                self?.ensureVolumeSelection()
            }
        }

        let unmountObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("Volume unmounted")
            guard let userInfo = notification.userInfo else {
                print("Couldn't get userInfo from unmounting notification")
                return
            }

            guard
                let volumeURL = userInfo[NSWorkspace.volumeURLUserInfoKey]
                    as? URL
            else {
                print("Couldn't get volume URL from unmounting notification")
                return
            }
            print("Unmounted volume URL: \(volumeURL.path)")

            self?.volumes.removeAll { $0.devicePath == volumeURL.path }

            if self?.selectedVolume == volumeURL.path {
                print("Selected volume was unmounted, making a new selection")
                self?.files = []
                self?.ensureVolumeSelection()
            }
        }

        self.observers.append(mountObserver)
        self.observers.append(unmountObserver)
        print("VolumeViewModel: Volume observers set up")
    }

    /// Removes volume observers.
    private func removeVolumeObservers() {
        self.observers.forEach {
            workspace.notificationCenter.removeObserver($0)
        }
        self.observers.removeAll()
        print("VolumeViewModel: Volume observers removed")
    }

    /// Loads all removable volumes connected to the system.
    /// - Returns: An array of `Volume` objects representing the removable volumes.
    func loadVolumes() -> [Volume] {
        print("loadVolumes: Loading volumes")
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeIsRemovableKey,
        ]
        guard
            let mountedVolumeURLs = fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: keys,
                options: [.skipHiddenVolumes])
        else {
            print("loadVolumes: Failed to get mounted volume URLs")
            return []
        }

        return mountedVolumeURLs.compactMap { url -> Volume? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(keys))
                guard resourceValues.volumeIsRemovable == true else {
                    return nil
                }
                print(
                    "loadVolumes: Found removable volume: \(resourceValues.volumeName ?? "Unnamed Volume") at \(url.path)"
                )
                return Volume(
                    name: resourceValues.volumeName ?? "Unnamed Volume",
                    devicePath: url.path,
                    volumeUUID: resourceValues.volumeUUIDString ?? ""
                )
            } catch {
                print(
                    "Error getting resource values for volume at \(url): \(error)"
                )
                return nil
            }
        }
    }

    /// This function is called when the app is started or the selected volume was unmounted and we need to select a new volume
    /// Select the first available one, or nil if none are available
    func ensureVolumeSelection() {
        if let firstVolume = self.volumes.first {
            print("VolumeViewModel: Selecting first available volume")
            self.selectVolume(firstVolume.devicePath)
        } else {
            print("VolumeViewModel: No volumes available to select")
            self.selectVolume(nil)
        }
    }

    /// Selects a volume with the given ID.
    /// - Parameter id: The ID of the volume to select.
    func selectVolume(_ id: String?) {
        if id == self.selectedVolume {
            // Shouldn't happen, but we're selecting the already selected volume again
            // Do nothing
            return
        }

        // Either a new volume was selected, or volume was de-selected
        // In either case, empty out the files array
        Task {
            await MainActor.run {
                self.files = []
            }

            guard let id = id else {
                self.selectedVolume = nil
                return
            }

            print("VolumeViewModel: Selecting volume with ID: \(id)")
            await MainActor.run {
                self.selectedVolume = id
            }
            await enumerateFiles()
        }
    }

    /// Ejects the specified volume.
    /// - Parameter volume: The `Volume` to eject.
    /// - Throws: An error if the ejection fails.
    func ejectVolume(_ volume: Volume) {
        print("Attempting to eject volume: \(volume.name)")
        let url = URL(fileURLWithPath: volume.devicePath)
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            print("Successfully ejected volume: \(volume.name)")
        } catch {
            print("Error ejecting volume \(volume.devicePath): \(error)")
        }
    }

    func printMetadata(_ dict: [String: Any], indent: String = "") {
        for (key, value) in dict {
            if let nestedDict = value as? [String: Any] {
                print("\(indent)\(key):")
                printMetadata(nestedDict, indent: indent + "  ")
            } else {
                print("\(indent)\(key): \(value)")
            }
        }
    }

    func enumerateFiles() async {
        let fileManager = FileManager.default
        var batch: [File] = []

        guard let selectedVolume = selectedVolume else {
            print(
                "Couldn't get folder URL and thus couldn't enumerate files on \(selectedVolume ?? "nil")"
            )
            return
        }

        let rootURL = URL(fileURLWithPath: selectedVolume)
        await MainActor.run {
            state = programState.enumeratingFiles
        }
        print("Enumerating files in \(rootURL.path)")

        do {
            let resourceKeys: Set<URLResourceKey> = [
                .creationDateKey, .contentModificationDateKey, .fileSizeKey,
            ]
            let enumerator = fileManager.enumerator(
                at: rootURL, includingPropertiesForKeys: Array(resourceKeys))
            print("Enumerator: \(String(describing: enumerator))")

            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(
                atPath: rootURL.path, isDirectory: &isDirectory)
                || !isDirectory.boolValue
            {
                print(
                    "Error: Specified path does not exist or is not a directory"
                )
            }

            while let fileURL = enumerator?.nextObject() as? URL {
                print("Checking fileURL.path: \(fileURL.path)")
                guard fileURL.hasDirectoryPath == false else {
                    if fileURL.lastPathComponent == "THMBNL" {
                        enumerator?.skipDescendants()
                    }
                    continue
                }
                let mediaType = determineMediaType(for: fileURL.path)
                if mediaType == MediaType.unknown { continue }

                let resourceValues = try fileURL.resourceValues(
                    forKeys: resourceKeys)
                let creationDate = resourceValues.creationDate
                let modificationDate = resourceValues.contentModificationDate
                let size = Int64(resourceValues.fileSize ?? 0)

                // mediaDate is a date which stores the date the media was created
                // Because Swift pretends date is UTC, we convert all dates back or
                // forward by the current timezone. Before using this value, just
                // remember to convert it "back to current timezone" to get the local date
                var mediaDate: Date?

                if mediaType == MediaType.video {
                    do {
                        // Create an AVAsset for the video file
                        let asset = AVURLAsset(url: fileURL)

                        if let creationDate = try await asset.load(.creationDate) {
                            if let dateValue = try await creationDate.load(.dateValue) {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                                dateFormatter.timeZone = TimeZone.current

                                mediaDate = dateValue
                                print("Creation date date from metadata: \(dateFormatter.string(from: dateValue))")
                            }
                        }

                    } catch {
                        print("Error loading video metadata: \(error.localizedDescription)")
                    }
                }

                if mediaType == MediaType.image {
                    if let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
                    {
                        // Get DateTimeOriginal from Exif or TIFF
                        let exifMetadata = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
                        let tiffMetadata = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

                        let dateTimeOriginal: String? =
                            exifMetadata?["DateTimeOriginal"] as? String ?? tiffMetadata?["DateTime"] as? String

                        if let dateTimeOriginal = dateTimeOriginal {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                            mediaDate = dateFormatter.date(from: dateTimeOriginal)
                            print("DateTimeOriginal: \(dateTimeOriginal)")
                            // mediaDate now has a mangled date that needs to be moved
                            // back by "current timezone" before being used
                        } else {
                            print("DateTimeOriginal not found in Exif or TIFF metadata.")
                        }
                    } else {
                        print("Failed to retrieve image metadata.")
                    }
                }

                if mediaDate == nil {
                    // Convert creation and modification dates to local time
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                    dateFormatter.timeZone = TimeZone.current

                    if let creationDate = creationDate {
                        mediaDate = creationDate
                        print("Creation date (local): \(dateFormatter.string(from: creationDate))")
                    } else if let modificationDate = modificationDate {
                        mediaDate = modificationDate
                        print("Modification date (local): \(dateFormatter.string(from: modificationDate))")
                    }
                }

                let file = File(
                    sourcePath: fileURL.path,
                    mediaType: mediaType,
                    date: mediaDate,
                    size: size
                )

                batch.append(file)

                if batch.count >= 50 {
                    await appendFiles(batch)
                    batch.removeAll()
                }
            }

            if !batch.isEmpty {
                await appendFiles(batch)
                batch.removeAll()
            }
            print("Done with enumeration")
        } catch {
            print("Error enumerating files: \(error)")
        }

        await MainActor.run {
            state = programState.idle
        }
    }

    func appendFiles(_ batch: [File]) async {
        await MainActor.run {
            files.append(contentsOf: batch)
        }
    }

    func projectDestinationFilenames() async {

    }

    func importFiles() async {
        print("Importing files")
        let fileManager = FileManager.default
        if !fileManager.isWritableFile(atPath: settingDestinationFolder) {
            await MainActor.run {
                self.error = errorState.destinationFolderNotWritable
            }
            return
        } else {
            await MainActor.run {
                self.error = errorState.none
            }
        }

        print("Total source files: \(files.count)")

        await projectDestinationFilenames()

        print("Import done")
    }
}
