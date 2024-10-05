import AppKit

class UILogic {
    static func toggleSidebar() {
        print("UILogic: Toggle sidebar called")
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    // Add other UI-related logic methods here
}
