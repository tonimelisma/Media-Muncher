import AppKit

/// `UILogic` contains utility methods for UI-related operations.
class UILogic {
    /// Toggles the visibility of the sidebar.
    static func toggleSidebar() {
        print("UILogic: Toggle sidebar called")
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    // TODO: Add other UI-related logic methods here
}
