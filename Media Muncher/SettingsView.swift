import SwiftUI

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

            Toggle(
                "Organize into Date Folders",
                isOn: $appState.organizeDateFolders
            )
            .onChange(of: appState.organizeDateFolders) { oldValue, newValue in
                print(
                    "SettingsView: Organize into Date Folders changed from \(oldValue) to \(newValue)"
                )
            }

            Toggle(
                "Rename Files with Date and Time",
                isOn: $appState.renameDateTimeFiles
            )
            .onChange(of: appState.renameDateTimeFiles) { oldValue, newValue in
                print(
                    "SettingsView: Rename Files with Date and Time changed from \(oldValue) to \(newValue)"
                )
            }

            Toggle(
                "Verify Import Integrity",
                isOn: $appState.verifyImportIntegrity
            )
            .onChange(of: appState.verifyImportIntegrity) { oldValue, newValue in
                print(
                    "SettingsView: Verify Import Integrity changed from \(oldValue) to \(newValue)"
                )
            }
        }
        .padding(20)
        .frame(width: 450, height: 300)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppState())
    }
}
