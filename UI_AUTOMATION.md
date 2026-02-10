# UI Automation with Claude Code

How to launch, interact with, screenshot, and inspect Media Muncher from the terminal. All tools are built into macOS — no MCP servers or third-party installs required.

## Prerequisites

The terminal running Claude Code needs these permissions in **System Settings > Privacy & Security**:

| Permission | What it enables |
|---|---|
| **Screen Recording** | `screencapture -l` to capture specific windows |
| **Accessibility** | `osascript` reading/clicking UI elements via System Events |

Verify:
```bash
screencapture -x /tmp/test.png && echo "Screen Recording OK"
swift -e 'import ApplicationServices; print("AX trusted:", AXIsProcessTrusted())'
```

## Quick Reference

### Build, launch, and screenshot

```bash
# Build
xcodebuild -scheme "Media Muncher" build

# Launch
open "/path/to/DerivedData/.../Debug/Media Muncher.app"
sleep 2

# Quit gracefully (saves state, like Cmd+Q)
osascript -e 'tell application "Media Muncher" to quit'

# Re-launch (quit first, then open)
osascript -e 'tell application "Media Muncher" to quit'
sleep 0.5
open "/path/to/DerivedData/.../Debug/Media Muncher.app"
sleep 2

# Find the app's built path
xcodebuild -scheme "Media Muncher" -showBuildSettings 2>/dev/null \
  | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}'

# Get window ID for screencapture
swift -e '
import Cocoa
if let wins = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] {
    for w in wins {
        if let owner = w["kCGWindowOwnerName"] as? String, owner == "Media Muncher",
           let name = w["kCGWindowName"] as? String, !name.isEmpty {
            print("WindowID=\(w["kCGWindowNumber"] as? Int ?? -1) Name=\(name)")
        }
    }
}
'

# Capture a specific window (non-interactive, no shadow)
screencapture -l <WINDOW_ID> /tmp/screenshot.png
```

### Read the UI element tree

```bash
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        entire contents of window 1
    end tell
end tell'
```

This returns every element: buttons, checkboxes, static text labels, groups, toolbar items. Elements are referenced by index within their parent (e.g. `checkbox 4 of group 1 of window "Media Muncher Settings"`).

### Interact with the app

```bash
# Bring app to front
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        set frontmost to true
    end tell
end tell'

# Keyboard shortcut (Cmd+,)
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        keystroke "," using command down
    end tell
end tell'

# Click a checkbox by index
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        click checkbox 4 of group 1 of window "Media Muncher Settings"
    end tell
end tell'

# Click a toolbar button
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        click button 1 of toolbar 1 of window "Media Muncher"
    end tell
end tell'

# Read checkbox state (0 = unchecked, 1 = checked)
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        value of checkbox 3 of group 1 of window "Media Muncher Settings"
    end tell
end tell'

# Read window properties (position, size, title)
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        get properties of window 1
    end tell
end tell'

# Resize window to a consistent size for screenshots
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        set position of window 1 to {100, 100}
        set size of window 1 to {1200, 800}
    end tell
end tell'
```

## Media Muncher Window Names

| Window | Title for `app.windows["..."]` |
|---|---|
| Main window | `"Media Muncher"` |
| Settings | `"Media Muncher Settings"` |

The settings window title follows the macOS SwiftUI convention: `"<AppName> Settings"`.

## Settings Checkbox Map

The settings window has 8 checkboxes in `group 1`:

| Index | Setting |
|---|---|
| checkbox 1 | Organize into date-based folders |
| checkbox 2 | Rename files by date and time |
| checkbox 3 | Images |
| checkbox 4 | Videos |
| checkbox 5 | Audio |
| checkbox 6 | RAW |
| checkbox 7 | Delete originals after successful import |
| checkbox 8 | Eject volume after successful import |

## Typical Workflow

1. **Build and launch** the app
2. **Get window IDs** via Swift CGWindowList snippet
3. **Screenshot** the window with `screencapture -l <ID> /tmp/shot.png`
4. **Read the screenshot** — Claude can view PNG files directly
5. **Interact** via osascript (click, type, keyboard shortcuts)
6. **Screenshot again** to verify the result
7. **Read the element tree** if you need to find specific controls

## XCUITest Suite

A formal XCUITest target (`Media MuncherUITests`) also exists with 20 tests covering accessibility audits, window structure, settings controls, and empty-state verification. These are **skipped by default** in the scheme to avoid ~96s of screen flickering during normal test runs.

```bash
# Run UI tests explicitly
xcodebuild -scheme "Media Muncher" test -only-testing:"Media MuncherUITests"
```

The tests use accessibility identifiers (e.g. `"importButton"`, `"settingsButton"`, `"volumeList"`) added to key UI elements across all views.
