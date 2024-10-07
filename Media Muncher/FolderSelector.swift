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

    var body: some View {
        PopUpButton(selection: Binding(
            get: { self.defaultSavePath },
            set: { self.handleSelection($0) }
        )) {
            Text(URL(fileURLWithPath: defaultSavePath).lastPathComponent).tag(defaultSavePath)

            Divider()

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
        .background(Color.white)
        .fileImporter(
            isPresented: $isDirectoryPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                self.defaultSavePath = url.path
                UserDefaults.standard.set(url.path, forKey: "defaultSavePath")
            }
        }
    }

    /// Handles the selection of a folder.
    /// - Parameter selection: The selected folder path or action.
    func handleSelection(_ selection: String) {
        switch selection {
        case "other":
            isDirectoryPickerPresented = true
        case "advanced":
            openSettings()
        default:
            defaultSavePath = selection
            UserDefaults.standard.set(selection, forKey: "defaultSavePath")
        }
    }
}

/// `PopUpButton` is a custom button that displays a menu of options.
struct PopUpButton<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    var content: () -> Content

    init(selection: Binding<SelectionValue>, @ViewBuilder content: @escaping () -> Content) {
        self._selection = selection
        self.content = content
    }

    var body: some View {
        Picker(selection: $selection, label: EmptyView()) {
            content()
        }
        .pickerStyle(MenuPickerStyle())
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
