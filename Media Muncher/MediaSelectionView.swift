import SwiftUI

struct MediaSelectionView: View {
    @StateObject var viewModel = MediaSelectionViewModel()
    @EnvironmentObject var coordinator: Coordinator

    var body: some View {
        VStack {
            Text("Media Selection")
                .font(.title)
            Button("Back") {
                coordinator.presentVolumesView()
            }
            Button("Settings") {
                coordinator.presentSettingsView()
            }
        }
    }
}

struct MediaSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        MediaSelectionView()
            .environmentObject(Coordinator(settings: Settings()))
    }
}
