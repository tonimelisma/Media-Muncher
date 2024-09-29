import SwiftUI

struct ContentView: View {
    @StateObject var coordinator = Coordinator(settings: Settings())

    var body: some View {
        ZStack {
            if coordinator.currentView == .volumes {
                VolumesView()
            } else if coordinator.currentView == .mediaSelection {
                MediaSelectionView()
            }
        }
        .environmentObject(coordinator)
        .sheet(isPresented: $coordinator.showSettings) {
            SettingsView()
                .environmentObject(coordinator.settings)
                .environmentObject(coordinator)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
