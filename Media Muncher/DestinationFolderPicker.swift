//
//  DestinationFolderPicker.swift
//  Media Muncher
//
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import AppKit

/// A SwiftUI wrapper around `NSPopUpButton` that lists preset user folders, an optional custom folder, and an “Other…” entry.
///
/// Behaviour spec:
/// 1. The popup shows the icon + folder name of the current destination.
/// 2. Clicking it opens a menu that extends upward *and* downward.
/// 3. Top of menu: Pictures, Movies, Music, Desktop, Documents, Downloads — in that order.
/// 4. If the user previously chose a custom folder, it is shown after a separator.
/// 5. The final item is “Other…” which opens an `NSOpenPanel` for directory selection.
/// 6. When a folder is selected we immediately try to write a temporary file; if that fails (e.g. user denied TCC)
///    an `NSAlert` is displayed and the selection reverts to the previous valid value.
struct DestinationFolderPicker: NSViewRepresentable {
    @EnvironmentObject var settingsStore: SettingsStore

    // MARK: - NSViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.menu = NSMenu()
        popup.target = context.coordinator
        popup.action = #selector(Coordinator.popupSelectionChanged(_:))

        context.coordinator.popupButton = popup
        context.coordinator.rebuildMenu()
        return popup
    }

    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        // The underlying menu might need updating if SettingsStore changed.
        context.coordinator.rebuildMenu()
    }

    // MARK: - Coordinator
    class Coordinator: NSObject {
        private let parent: DestinationFolderPicker
        weak var popupButton: NSPopUpButton?

        private var previousValidURL: URL?

        init(_ parent: DestinationFolderPicker) {
            self.parent = parent
            self.previousValidURL = parent.settingsStore.destinationURL
        }

        // MARK: - Menu construction
        func rebuildMenu() {
            guard let popupButton else { return }

            let store = parent.settingsStore
            let currentSelection = store.destinationURL
            popupButton.menu?.removeAllItems()

            let presets: [(name: String, url: URL)] = Self.standardFolders()
            for preset in presets {
                popupButton.menu?.addItem(self.menuItem(for: preset.url, title: preset.name))
            }

            // Separator after presets
            popupButton.menu?.addItem(NSMenuItem.separator())


            // “Other…” item
            let otherItem = NSMenuItem(title: "Other…", action: #selector(showOpenPanel), keyEquivalent: "")
            otherItem.target = self
            if let icon = Self.folderIcon(for: nil) {
                icon.size = NSSize(width: 16, height: 16)
                otherItem.image = icon
            }
            popupButton.menu?.addItem(otherItem)

            // Update selection state
            if let current = currentSelection,
               let match = popupButton.menu?.items.first(where: { ($0.representedObject as? URL) == current }) {
                popupButton.select(match)
            }
            updateCheckmarks()
        }

        // MARK: - Actions
        @objc func popupSelectionChanged(_ menuItem: NSMenuItem) {
            guard let url = menuItem.representedObject as? URL else { return }

            // Attempt to validate write access.
            if parent.settingsStore.trySetDestination(url) {
                previousValidURL = url
                popupButton?.select(menuItem)
                updateCheckmarks()
            } else {
                // Access failed; revert selection and show alert.
                if let prev = previousValidURL,
                   let match = popupButton?.menu?.items.first(where: { ($0.representedObject as? URL) == prev }) {
                    popupButton?.select(match)
                }
                presentPermissionAlert(for: url)
                updateCheckmarks()
            }
        }

        // Presents an open panel for picking a custom folder.
        @objc private func showOpenPanel() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"

            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }

                if self.parent.settingsStore.trySetDestination(url) {
                    self.previousValidURL = url
                    self.rebuildMenu()
                    self.updateCheckmarks()
                } else {
                    self.presentPermissionAlert(for: url)
                    self.updateCheckmarks()
                }
            }
        }

        // MARK: - Helpers
        private func menuItem(for url: URL, title: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(popupSelectionChanged(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            if let icon = Self.folderIcon(for: url) {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            item.state = (url == parent.settingsStore.destinationURL) ? .on : .off
            return item
        }

        private static func folderIcon(for url: URL?) -> NSImage? {
            if let url {
                return NSWorkspace.shared.icon(forFile: url.path)
            } else {
                // Generic blue folder icon for "Other…"
                return NSImage(named: NSImage.folderName)
            }
        }

        private static func standardFolders() -> [(String, URL)] {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let map: [(String, String)] = [
                ("Pictures", "Pictures"),
                ("Movies", "Movies"),
                ("Music", "Music"),
                ("Desktop", "Desktop"),
                ("Documents", "Documents"),
                ("Downloads", "Downloads")
            ]
            return map.compactMap { (name, path) in
                let url = home.appendingPathComponent(path)
                return fm.fileExists(atPath: url.path) ? (name, url) : nil
            }
        }

        private func presentPermissionAlert(for url: URL) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Permission Denied"
            alert.informativeText = "Media Muncher needs permission to access your \(url.lastPathComponent) folder. Without access, files cannot be imported here."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open System Settings")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                if let prefURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                    NSWorkspace.shared.open(prefURL)
                }
            }
        }

        private func updateCheckmarks() {
            guard let menuItems = popupButton?.menu?.items else { return }
            let current = parent.settingsStore.destinationURL?.standardizedFileURL
            for item in menuItems {
                if let url = item.representedObject as? URL {
                    item.state = (url.standardizedFileURL == current) ? .on : .off
                } else {
                    item.state = .off
                }
            }
        }
    }
} 