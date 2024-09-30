import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultSavePath") private var defaultSavePath = NSHomeDirectory()
    @AppStorage("autoEjectAfterCopy") private var autoEjectAfterCopy = false
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Auto-eject after copying", isOn: $autoEjectAfterCopy)
                Toggle("Show notifications", isOn: $showNotifications)
            }
            
            Section(header: Text("File Management")) {
                HStack {
                    Text("Default save path:")
                    Spacer()
                    PathControl(url: Binding(
                        get: { URL(fileURLWithPath: defaultSavePath) },
                        set: { defaultSavePath = $0.path }
                    ))
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 200)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
