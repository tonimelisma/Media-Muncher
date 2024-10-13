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
                "Organize into folders by date",
                isOn: $appState.organizeDateFolders
            )
            .onChange(of: appState.organizeDateFolders) { oldValue, newValue in
                print(
                    "SettingsView: Organize into Date Folders changed from \(oldValue) to \(newValue)"
                )
            }

            Toggle(
                "Rename files with date and time",
                isOn: $appState.renameDateTimeFiles
            )
            .onChange(of: appState.renameDateTimeFiles) { oldValue, newValue in
                print(
                    "SettingsView: Rename Files with Date and Time changed from \(oldValue) to \(newValue)"
                )
            }

            Toggle(
                "Verify integrity after importing",
                isOn: $appState.verifyImportIntegrity
            )
            .onChange(of: appState.verifyImportIntegrity) { oldValue, newValue in
                print(
                    "SettingsView: Verify Import Integrity changed from \(oldValue) to \(newValue)"
                )
            }

            Toggle(
                "Automatically choose new name for unique imports",
                isOn: $appState.autoChooseUniqueName
            )
            .onChange(of: appState.autoChooseUniqueName) { oldValue, newValue in
                print(
                    "SettingsView: Automatically choose new name for unique imports changed from \(oldValue) to \(newValue)"
                )
            }
        }
        .padding(20)
        .frame(width: 600, height: 300)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(AppState())
    }
}
