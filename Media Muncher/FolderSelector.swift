import SwiftUI

/// `FolderSelector` is a custom view for selecting a folder path.
struct FolderSelector: View {
    @Binding var defaultSavePath: String
    var showAdvancedSettings: Bool
    @State private var isDirectoryPickerPresented = false

    @Environment(\.openSettings) private var openSettings

    /// An array of default folder locations.
    let defaultFolders = [
        ("Documents", FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first),
        ("Desktop", FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first),
        ("Downloads", FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first),
        ("Pictures", FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first),
        ("Movies", FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first),
        ("Music", FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first),
    ]

    private var currentFolderName: String {
        let result: String
        if let presetFolder = defaultFolders.first(where: { $0.1?.path == defaultSavePath }) {
            result = presetFolder.0
        } else {
            result = URL(fileURLWithPath: defaultSavePath).lastPathComponent
        }
        return result
    }

    private func isPresetFolder(_ path: String) -> Bool {
        let result = defaultFolders.contains { _, url in url?.path == path }
        return result
    }

    var body: some View {
        PopUpButton(selection: Binding(
            get: {
                return self.defaultSavePath
            },
            set: { newValue in
                self.handleSelection(newValue)
            }
        ), label: currentFolderName) {
            if !isPresetFolder(defaultSavePath) {
                Text(URL(fileURLWithPath: defaultSavePath).lastPathComponent).tag(defaultSavePath)
                Divider()
            }

            ForEach(defaultFolders, id: \.0) { folderName, folderURL in
                if let url = folderURL {
                    Text(folderName).tag(url.path)
                }
            }

            Divider()

            Text("Other folder...").tag("other")

            if showAdvancedSettings {
                Divider()
                Text("Advanced folder settings...").tag("advanced")
            }
        }
        .frame(width: 200)
        .fileImporter(
            isPresented: $isDirectoryPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                print("FolderSelector: File importer selected path: \(url.path)")
                self.defaultSavePath = url.path
                UserDefaults.standard.set(url.path, forKey: "defaultSavePath")
            }
        }
        .onChange(of: defaultSavePath) { oldValue, newValue in
            print("FolderSelector: defaultSavePath changed from \(oldValue) to \(newValue)")
        }
    }

    /// Handles the selection of a folder.
    /// - Parameter selection: The selected folder path or action.
    func handleSelection(_ selection: String) {
        print("FolderSelector: handleSelection called with: \(selection)")
        switch selection {
        case "other":
            print("FolderSelector: 'Other folder...' selected")
            isDirectoryPickerPresented = true
        case "advanced":
            print("FolderSelector: 'Advanced folder settings...' selected")
            openSettings()
        default:
            print("FolderSelector: Folder selected: \(selection)")
            defaultSavePath = selection
            UserDefaults.standard.set(selection, forKey: "defaultSavePath")
        }
    }
}

/// `PopUpButton` is a custom button that displays a menu of options.
struct PopUpButton<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    var label: String
    var content: () -> Content

    init(selection: Binding<SelectionValue>, label: String, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.label = label
        self.content = content
    }

    var body: some View {
        Picker(selection: $selection, label: EmptyView()) {
            content()
        }
        .pickerStyle(MenuPickerStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FolderSelector_Previews: PreviewProvider {
    static var previews: some View {
        FolderSelector(defaultSavePath: .constant("/Users/example/Documents"), showAdvancedSettings: true)
    }
}
