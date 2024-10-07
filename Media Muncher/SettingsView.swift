import SwiftUI

/// `SettingsView` displays and manages application settings.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            HStack(alignment: .firstTextBaseline) {
                Text("Import To:")
                    .frame(width: 120, alignment: .trailing)
                
                FolderSelector(
                    defaultSavePath: $appState.defaultSavePath,
                    showAdvancedSettings: false)
            }
            
            Text(appState.defaultSavePath)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 450, height: 150)
    }
}

/// Preview provider for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppState())
    }
}
