import SwiftUI
import AppKit

struct PathControl: NSViewRepresentable {
    @Binding var url: URL
    
    func makeNSView(context: Context) -> NSPathControl {
        let pathControl = NSPathControl()
        pathControl.pathStyle = .popUp
        pathControl.delegate = context.coordinator
        return pathControl
    }
    
    func updateNSView(_ nsView: NSPathControl, context: Context) {
        nsView.url = url
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSPathControlDelegate {
        var parent: PathControl
        
        init(_ parent: PathControl) {
            self.parent = parent
        }
        
        func pathControl(_ pathControl: NSPathControl, willPopUp menu: NSMenu) {
            let chooseItem = NSMenuItem(title: "Choose...", action: #selector(chooseLocation), keyEquivalent: "")
            chooseItem.target = self
            menu.insertItem(chooseItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        }
        
        @objc func chooseLocation() {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            
            if panel.runModal() == .OK {
                if let url = panel.url {
                    parent.url = url
                }
            }
        }
    }
}
