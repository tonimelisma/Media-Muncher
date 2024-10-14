import SwiftUI

class MediaFilesViewModel: ObservableObject {
    @Published var displayedMediaFiles: [MediaFile] = []
    private var timer: Timer?
    private var appState: AppState?

    init() {
        setupTimer()
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            print("MediaFilesViewModel: Timer fired")
            self?.updateDisplayedFiles()
        }
    }

    func updateDisplayedFiles() {
        DispatchQueue.main.async { [weak self] in
            if let appState = self?.appState {
                self?.displayedMediaFiles = appState.mediaFiles
                print("MediaFilesViewModel: Updated displayed files. Count: \(appState.mediaFiles.count)")
            }
        }
    }

    func setAppState(_ appState: AppState) {
        self.appState = appState
        print("MediaFilesViewModel: AppState set")
    }

    deinit {
        timer?.invalidate()
    }
}
