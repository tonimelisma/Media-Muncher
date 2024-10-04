import Foundation
import AppKit

class VolumeObserver {
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    var onVolumeChange: () -> Void
    
    init(onVolumeChange: @escaping () -> Void) {
        self.onVolumeChange = onVolumeChange
        setupVolumeObserver()
    }
    
    deinit {
        tearDownVolumeObserver()
    }
    
    private func setupVolumeObserver() {
        print("VolumeObserver: Setting up volume observer")
        let notificationCenter = NotificationCenter.default

        mountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification, object: nil, queue: nil
        ) { [weak self] _ in
            print("VolumeObserver: Volume mounted notification received")
            self?.onVolumeChange()
        }

        unmountObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification, object: nil, queue: nil
        ) { [weak self] _ in
            print("VolumeObserver: Volume unmounted notification received")
            self?.onVolumeChange()
        }
    }

    private func tearDownVolumeObserver() {
        print("VolumeObserver: Tearing down volume observer")
        if let observer = mountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = unmountObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
