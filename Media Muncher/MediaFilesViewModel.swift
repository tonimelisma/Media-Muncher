import SwiftUI
import Combine

class MediaFilesViewModel: ObservableObject {
    @Published var displayedMediaFiles: [MediaFile] = []
    private var timer: Timer?

    init() {
        setupTimer()
    }

    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func updateDisplayedFiles(with newFiles: [MediaFile]) {
        DispatchQueue.main.async {
            self.displayedMediaFiles = newFiles
        }
    }

    deinit {
        timer?.invalidate()
    }
}
