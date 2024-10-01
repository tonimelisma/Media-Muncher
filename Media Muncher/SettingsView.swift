import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultSavePath") private var defaultSavePath = NSHomeDirectory()

    var body: some View {
        Form {
            HStack(alignment: .firstTextBaseline) {
                Text("Import To:")
                    .frame(width: 120, alignment: .trailing)
                
                FolderSelector(defaultSavePath: $defaultSavePath, showAdvancedSettings: false)
            }
            
            Text(defaultSavePath)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 450, height: 150)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
