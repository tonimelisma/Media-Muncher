import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var coordinator: Coordinator

    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
            Toggle("Some Setting", isOn: $settings.someSetting)
            Button("Close") {
                coordinator.dismissSettingsView()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(Settings())
            .environmentObject(Coordinator(settings: Settings()))
    }
}
