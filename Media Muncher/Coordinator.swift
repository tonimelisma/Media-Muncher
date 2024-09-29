import SwiftUI

class Coordinator: ObservableObject {
    @Published var currentView: ViewType = .volumes
    @Published var showSettings = false
    let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func presentMediaSelectionView() {
        currentView = .mediaSelection
    }

    func presentVolumesView() {
        currentView = .volumes
    }

    func presentSettingsView() {
        showSettings = true
    }

    func dismissSettingsView() {
        showSettings = false
    }
}

enum ViewType {
    case volumes
    case mediaSelection
}
