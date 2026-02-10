# UI Automation with Claude Code

This document describes how Claude Code (or any LLM coding agent) can interact with Media Muncher's UI for testing, exploration, and quality assurance. It covers seven workflows, the tools that enable them, and concrete examples for this project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Tools Reference](#tools-reference)
- [Workflows](#workflows)
  - [1. Visual Bug Detection](#1-visual-bug-detection)
  - [2. Exploratory Testing](#2-exploratory-testing)
  - [3. Regression Testing](#3-regression-testing)
  - [4. Accessibility Auditing](#4-accessibility-auditing)
  - [5. User Flow Simulation](#5-user-flow-simulation)
  - [6. Design System Verification](#6-design-system-verification)
  - [7. Live Development Feedback Loop](#7-live-development-feedback-loop)

---

## Integration with Testing Flow

### Formal Tests (run via `xcodebuild test`)

The `Media MuncherUITests` XCUITest target contains deterministic, pass/fail UI tests:

| Test Class | What it covers |
|---|---|
| `AccessibilityAuditTests` | Apple's `performAccessibilityAudit` for main and settings windows; screenshot capture |
| `MainWindowStructureTests` | Window exists, settings button, import button (exists + disabled), sidebar presence |
| `SettingsWindowTests` | Cmd+, opens settings, all toggle controls present, Cmd+W closes |
| `EmptyStateTests` | No-volume guidance text, no media grid, no error banner on clean launch |

These tests use accessibility identifiers (e.g., `"importButton"`, `"settingsButton"`, `"volumeList"`) for reliable element queries.

### Agent-Driven Workflows (not in `xcodebuild test`)

These require Claude vision, adaptive reasoning, or hardware and stay outside the formal test suite:

| Workflow | When to trigger |
|---|---|
| Visual Bug Detection | After any UI change, before commit |
| Exploratory Testing | On demand — "explore the current UI" |
| Regression Testing (visual) | Before/after UI refactors |
| User Flow Simulation | On demand — requires USB volume |
| Design System Verification | Periodically or before releases |
| Live Development Feedback Loop | Automatically during UI development (RenderPreview or screenshot) |

### How They Connect

1. **XCUITests capture screenshots** and attach them to the xcresult bundle. These screenshots can feed into agent-driven visual analysis.
2. **Accessibility audit failures** in XCUITests identify gaps that the agent should fix (add `.accessibilityLabel()`, `.accessibilityValue()`, etc.).
3. **`#Preview` macros** on views enable the `RenderPreview` MCP tool for the live development feedback loop (workflow 7).
4. **Visual verification** (DoD step 3) is performed by the agent during development, not as a blocking CI check.

---

## Prerequisites

### macOS Permissions

The terminal application running Claude Code (Terminal.app, iTerm2, etc.) must have the following permissions granted in **System Settings > Privacy & Security**:

| Permission | What it enables | Where to grant |
|---|---|---|
| **Screen Recording** | `screencapture`, any screenshot MCP tool, `CGWindowListCreateImage` | Privacy & Security > Screen Recording |
| **Accessibility** | Reading UI element hierarchy, clicking buttons, typing text, `AXUIElement` APIs | Privacy & Security > Accessibility |
| **Automation** | `osascript` controlling specific apps via System Events | Privacy & Security > Automation |

After granting permissions, **restart the terminal** for them to take effect. Verify with:

```bash
# Screen Recording — should produce a file without errors
screencapture -x /tmp/test.png

# Accessibility — should print "AX trusted: true"
swift -e 'import ApplicationServices; print("AX trusted:", AXIsProcessTrusted())'

# Automation — should list running apps without errors
osascript -e 'tell application "System Events" to get name of every process whose visible is true'
```

### Required Installs

| Tool | Purpose | Install | Required? |
|---|---|---|---|
| **screencapture** | Screenshot capture | Built into macOS | Yes (built-in) |
| **osascript** | AppleScript/JXA execution | Built into macOS | Yes (built-in) |
| **swift** | Compile/run Swift scripts | Xcode Command Line Tools | Yes (built-in with Xcode) |
| **cliclick** | Mouse/keyboard simulation | `brew install cliclick` | Recommended |
| **Peekaboo** | MCP server: screenshots + UI interaction | `npx @steipete/peekaboo-mcp` | Recommended |
| **AXorcist** | JSON-based accessibility tree CLI | Build from [GitHub](https://github.com/steipete/AXorcist) | Optional |
| **macapptree** | AX tree dump + annotated screenshots | `pip install macapptree` | Optional |
| **ImageMagick** | Pixel-level image comparison | `brew install imagemagick` | Optional (for regression diffs) |
| **XcodeBuildMCP** | Build/test Xcode projects via MCP | `npx -y xcodebuildmcp@latest mcp` | Optional |
| **Xcode 26.3 MCP** | Native Xcode MCP (RenderPreview, build, test) | Built into Xcode 26.3+ | Optional (requires Xcode 26.3) |
| **macos-ui-automation-mcp** | Accessibility-API UI automation MCP | [GitHub](https://github.com/mb-dev/macos-ui-automation-mcp) | Optional |
| **automation-mcp** | Full desktop automation MCP | `npm install automation-mcp` | Optional |
| **macos-automator-mcp** | AppleScript/JXA execution MCP | `npx @steipete/macos-automator-mcp` | Optional |
| **Hammerspoon** | Lua-scripted macOS automation | `brew install --cask hammerspoon` | Optional |
| **XCUITest** | Apple's UI testing framework | Built into Xcode | Optional (for formal UI test suites) |
| **swift-snapshot-testing** | Visual regression testing for SwiftUI | SPM: `pointfreeco/swift-snapshot-testing` | Optional |
| **ViewInspector** | Runtime SwiftUI view introspection | SPM: `nalexn/ViewInspector` | Optional |

---

## Tools Reference

### screencapture (built-in)

macOS built-in CLI for capturing screenshots. No install required.

**Key flags:**

```bash
# Full screen (silent, no shutter sound)
screencapture -x /tmp/screen.png

# Specific window by Window ID (silent, no shadow)
screencapture -x -o -l<windowid> /tmp/window.png

# Specific rectangular region
screencapture -x -R x,y,width,height /tmp/region.png

# With delay (seconds) — useful if app needs time to render
screencapture -x -T 2 /tmp/delayed.png

# As JPEG instead of PNG
screencapture -x -t jpg /tmp/screen.jpg

# Specific display (1 = main, 2 = secondary)
screencapture -x -D 1 /tmp/main.png
```

**All flags:** `-c` (clipboard), `-C` (include cursor), `-D` (specific display), `-l` (window ID), `-o` (no shadow), `-R` (rectangle), `-t` (format: png/jpg/tiff/pdf), `-T` (delay seconds), `-x` (silent), `-r` (no DPI metadata).

**Getting Window IDs** for the `-l` flag:

```bash
swift -e '
import CoreGraphics
if let wins = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
    for w in wins {
        let wid = w["kCGWindowNumber"] as? Int ?? 0
        let owner = w["kCGWindowOwnerName"] as? String ?? "?"
        let name = w["kCGWindowName"] as? String ?? ""
        let bounds = w["kCGWindowBounds"] as? [String: Any] ?? [:]
        if !name.isEmpty { print("WID:\(wid) [\(owner)] \"\(name)\" bounds:\(bounds)") }
    }
}
'
```

Then capture that specific window:

```bash
screencapture -x -o -l51598 /tmp/media-muncher.png
```

### osascript — AppleScript/JXA (built-in)

Apple's scripting bridge for controlling applications. Supports both AppleScript and JavaScript for Automation (JXA).

**Querying UI state:**

```bash
# List all visible processes
osascript -e 'tell application "System Events" to get name of every process whose visible is true'

# Get frontmost app
osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'

# Get window position and size
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        get {position, size} of window 1
    end tell
end tell'

# Dump entire UI element tree (requires Accessibility permission)
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        entire contents of window 1
    end tell
end tell'

# Read a specific element's properties
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        get {role, description, value, enabled} of every button of window 1
    end tell
end tell'
```

**Interacting with UI:**

```bash
# Click a button by name
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        click button "Import" of window 1
    end tell
end tell'

# Click a menu item
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        click menu item "Preferences..." of menu "Media Muncher" of menu bar 1
    end tell
end tell'

# Type text into frontmost field
osascript -e 'tell application "System Events" to keystroke "hello"'

# Press keyboard shortcut
osascript -e 'tell application "System Events" to keystroke "," using command down'

# Press special keys
osascript -e 'tell application "System Events" to key code 36' # Return
osascript -e 'tell application "System Events" to key code 48' # Tab

# Set window size
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        set size of window 1 to {800, 600}
    end tell
end tell'

# Set window position
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        set position of window 1 to {100, 100}
    end tell
end tell'
```

**JXA (JavaScript — better for machine parsing):**

```bash
# List windows with JSON-friendly output
osascript -l JavaScript -e '
var se = Application("System Events");
var proc = se.processes["Media Muncher"];
var wins = proc.windows();
JSON.stringify(wins.map(w => ({name: w.name(), position: w.position(), size: w.size()})));
'

# Find and click a button
osascript -l JavaScript -e '
var se = Application("System Events");
var proc = se.processes["Media Muncher"];
proc.windows[0].buttons.whose({name: "Import"})[0].click();
'

# Toggle dark mode
osascript -l JavaScript -e '
var se = Application("System Events");
se.appearancePreferences.darkMode = !se.appearancePreferences.darkMode();
'
```

### Swift CLI Scripts (built-in)

Swift scripts can be run with `swift -e '<code>'` for one-liners or `swift script.swift` for longer scripts. They have full access to AppKit, CoreGraphics, and ApplicationServices — native access to everything macOS provides.

**Accessibility tree inspection** (requires Accessibility permission):

```swift
#!/usr/bin/env swift
// Save as inspect-ui.swift, run with: swift inspect-ui.swift "Media Muncher"
import ApplicationServices
import AppKit

func inspectElement(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 5) {
    guard depth <= maxDepth else { return }
    let indent = String(repeating: "  ", count: depth)

    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    let role = roleRef as? String ?? "?"

    var titleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    let title = titleRef as? String ?? ""

    var valueRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
    let value = valueRef as? String ?? ""

    var idRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &idRef)
    let identifier = idRef as? String ?? ""

    var enabledRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledRef)
    let enabled = enabledRef as? Bool

    var posRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)

    var sizeRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

    var info = "[\(role)]"
    if !title.isEmpty { info += " title='\(title)'" }
    if !value.isEmpty { info += " value='\(value)'" }
    if !identifier.isEmpty { info += " id='\(identifier)'" }
    if let enabled = enabled { info += " enabled=\(enabled)" }

    print("\(indent)\(info)")

    var childrenRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
       let children = childrenRef as? [AXUIElement] {
        for child in children {
            inspectElement(child, depth: depth + 1, maxDepth: maxDepth)
        }
    }
}

let targetApp = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Media Muncher"
let apps = NSWorkspace.shared.runningApplications
if let app = apps.first(where: { $0.localizedName == targetApp }) {
    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    inspectElement(axApp)
} else {
    print("App '\(targetApp)' not found. Running apps:")
    let guiApps = apps.filter { $0.activationPolicy == .regular }
    for app in guiApps {
        print("  \(app.localizedName ?? "?") (PID: \(app.processIdentifier))")
    }
}
```

**Check accessibility trust:**

```bash
swift -e 'import ApplicationServices; print("AX trusted:", AXIsProcessTrusted())'
```

**List all GUI applications:**

```bash
swift -e '
import AppKit
let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
for app in apps {
    print("\(app.localizedName ?? "?") PID:\(app.processIdentifier) bundle:\(app.bundleIdentifier ?? "?")")
}
'
```

### cliclick (install via Homebrew)

Mouse and keyboard simulation from the command line. Useful when you know screen coordinates (from screencapture + AX tree) and need precise input.

```bash
brew install cliclick
```

**Commands:**

| Command | Syntax | Description |
|---|---|---|
| `c` | `c:x,y` | Click at coordinates |
| `rc` | `rc:x,y` | Right-click |
| `dc` | `dc:x,y` | Double-click |
| `tc` | `tc:x,y` | Triple-click |
| `m` | `m:x,y` | Move mouse |
| `dd` | `dd:x,y` | Mouse down (start drag) |
| `du` | `du:x,y` | Mouse up (end drag) |
| `kd` | `kd:cmd,shift` | Key down (modifiers: alt, cmd, ctrl, fn, shift) |
| `ku` | `ku:cmd` | Key up |
| `kp` | `kp:return` | Key press (return, tab, arrow keys, function keys, esc, space, delete) |
| `t` | `t:hello` | Type text |
| `w` | `w:500` | Wait milliseconds |
| `p` | `p` | Print current mouse position |

**Coordinate modifiers:** `+`/`-` for relative (e.g., `m:+50,+0` moves 50px right).

**Options:** `-m test` (dry run), `-m verbose` (print + execute), `-e N` (easing for natural mouse movement), `-r` (restore mouse position after).

**Examples:**

```bash
# Click at (400, 300), wait, type text
cliclick c:400,300 w:500 t:test

# Select all, copy (Cmd+A, Cmd+C)
cliclick kd:cmd t:a ku:cmd w:100 kd:cmd t:c ku:cmd

# Drag from (100,200) to (300,400)
cliclick dd:100,200 w:100 du:300,400
```

**Typical workflow with an LLM agent:**
1. Dump the AX tree to find the element's position
2. Use cliclick to click/type at those coordinates
3. Capture screenshot to verify result

### Peekaboo MCP Server (install via npx)

The most comprehensive macOS UI automation MCP server. Written in Swift by Peter Steinberger (creator of PSPDFKit). Uses ScreenCaptureKit for pixel-accurate window captures without stealing focus.

**Install and configure:**

Add to Claude Code's MCP config (`.claude/settings.json` or project `.mcp.json`):

```json
{
  "mcpServers": {
    "peekaboo": {
      "command": "npx",
      "args": ["@steipete/peekaboo-mcp"]
    }
  }
}
```

Requires macOS 15+, Xcode 16+, Swift 6.2.

**Key tools (25+):**

| Tool | What it does |
|---|---|
| `see` | Capture screenshot + annotate with element IDs for interaction. The primary "look at the screen" tool. |
| `image` | Capture a screenshot of a specific window or the full screen. |
| `click` | Click a UI element (by element ID from `see`, coordinates, or text match). |
| `type` | Type text into the focused element. |
| `press` | Press a key (Return, Tab, Escape, arrow keys, etc.). |
| `hotkey` | Press a keyboard shortcut (e.g., Cmd+S). |
| `scroll` | Scroll in a direction at a location. |
| `swipe` | Swipe gesture. |
| `drag` | Drag from one point to another. |
| `move` | Move the mouse cursor. |
| `dialog` | Drive open/save file dialogs (navigate, select, confirm). |
| `app` | Launch, quit, activate, or switch between applications. |
| `window` | Move, resize, focus, minimize, or fullscreen a window. |
| `space` | Manage macOS Spaces (switch, move windows between spaces). |
| `menu` | Click menu bar items by path (e.g., "File > Export"). |
| `menubar` | Interact with the system menu bar (WiFi, Bluetooth, etc.). |
| `dock` | Interact with the Dock. |
| `list` | List running applications or windows. |
| `run` | Execute a `.peekaboo.json` automation script (sequence of actions). |
| `agent` | Natural-language multi-step automation — describe what you want in English and Peekaboo chains the appropriate tools. |

**How `see` works:**

The `see` command captures a screenshot and overlays numbered labels on every interactive element. The LLM sees both the visual UI and element IDs, so it can say "click element 7" to press a specific button. This bridges the gap between vision (pixels) and semantics (what things are).

**Example `.peekaboo.json` automation script:**

```json
[
  {"tool": "app", "params": {"action": "launch", "name": "Media Muncher"}},
  {"tool": "see", "params": {}},
  {"tool": "click", "params": {"element": "Import"}},
  {"tool": "image", "params": {"window": "Media Muncher"}}
]
```

### AXorcist (build from source)

Swift library and CLI for accessibility tree queries with fuzzy matching. Powers Peekaboo's `see` command under the hood.

```bash
git clone https://github.com/steipete/AXorcist.git
cd AXorcist && swift build -c release
cp .build/release/axorc /usr/local/bin/
```

**JSON-based CLI protocol:**

```bash
# Find all buttons in an app
echo '{"command":"query","application":"Media Muncher",
"locator":{"criteria":[{"attribute":"AXRole","value":"AXButton"}]}}' | axorc --stdin

# Click a button by title
echo '{"command":"performAction","application":"Media Muncher",
"locator":{"criteria":[{"attribute":"AXTitle","value":"Import"}]},
"action":"AXPress"}' | axorc --stdin

# Find elements matching a regex
echo '{"command":"query","application":"Media Muncher",
"locator":{"criteria":[{"attribute":"AXTitle","match":"regex","value":"\\d+ files?"}]}}' | axorc --stdin
```

**Match modes:** `exact`, `contains`, `prefix`, `suffix`, `regex`.

### macapptree (install via pip)

Dumps the full accessibility tree as JSON and generates annotated screenshots with color-coded bounding boxes by element type.

```bash
pip install macapptree
```

```bash
# Dump AX tree + annotated screenshot for a specific app
python -m macapptree.main -a com.tonimelisma.MediaMuncher --oa /tmp/tree.json --os /tmp/screenshots

# All visible apps including menubar
python -m macapptree.main --all-apps --include-menubar --oa /tmp/all.json --os /tmp/shots
```

Output includes:
- `tree.json` — full nested accessibility hierarchy with roles, titles, values, positions, sizes
- Cropped app window screenshot
- Annotated screenshot with bounding boxes (buttons in one color, text fields in another, etc.)

### ImageMagick (install via Homebrew)

For pixel-level visual diffs between screenshots. Used in the regression testing workflow.

```bash
brew install imagemagick
```

```bash
# Create a visual diff image (changed pixels highlighted)
compare baseline.png current.png -compose src diff.png

# Get a numerical similarity metric (0 = identical)
compare -metric AE baseline.png current.png null: 2>&1
```

### XcodeBuildMCP (install via npx)

MCP server that lets AI agents build, test, and manage Xcode projects. 4,200+ stars on GitHub. This is the primary way Claude Code can trigger builds and tests without raw `xcodebuild` commands.

**Install and configure:**

Add to Claude Code's MCP config (`.claude/settings.json` or project `.mcp.json`):

```json
{
  "mcpServers": {
    "xcodebuild": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"]
    }
  }
}
```

**Key tools:**

| Tool | What it does |
|---|---|
| `xcodebuild_build` | Build a scheme for a destination (macOS, simulator, device) |
| `xcodebuild_test` | Run tests for a scheme |
| `xcodebuild_list_schemes` | Discover available schemes in the project |
| `xcodebuild_clean` | Clean build artifacts |
| `simulator_list` | List available simulators |
| `simulator_boot` | Boot a simulator |
| `simulator_install` | Install an app in the simulator |
| `simulator_launch` | Launch an app in the simulator |
| `simulator_open` | Open Simulator.app |

**Relevance to Media Muncher:** Build and test without needing to remember `xcodebuild` flags. The agent can discover schemes, build, run all tests, and run specific test classes — all through MCP tools. Does not provide UI inspection or interaction.

### Xcode 26.3 Native MCP (built into Xcode)

Released February 3, 2026. Xcode natively integrates the Claude Agent SDK and exposes 20 MCP tools via `xcrun mcpbridge`. This is Apple's official approach to AI-assisted development.

**Setup:**

Xcode 26.3 registers itself as an MCP server automatically. Configure in Claude Code's MCP config:

```json
{
  "mcpServers": {
    "xcode": {
      "command": "xcrun",
      "args": ["mcpbridge"]
    }
  }
}
```

**The 20 tools:**

| Category | Tools |
|---|---|
| **File ops** | `XcodeRead`, `XcodeWrite`, `XcodeUpdate` (str_replace edits), `XcodeGlob`, `XcodeGrep`, `XcodeLS`, `XcodeMakeDir`, `XcodeRM`, `XcodeMV` |
| **Build/test** | `BuildProject`, `GetBuildLog`, `RunAllTests`, `RunSomeTests`, `GetTestList` |
| **Diagnostics** | `XcodeListNavigatorIssues`, `XcodeRefreshCodeIssuesInFile` |
| **Advanced** | `ExecuteSnippet` (Swift REPL), `RenderPreview` (capture SwiftUI preview images), `DocumentationSearch` (Apple docs + WWDC transcripts), `XcodeListWindows` |

**RenderPreview — the key tool for UI feedback:**

`RenderPreview` captures SwiftUI Preview images without launching the full app. The agent writes SwiftUI code, calls `RenderPreview` to see the result, identifies issues, fixes them, and re-renders. This is the fastest visual feedback loop — no app launch required.

```
1. Agent edits a SwiftUI view
2. Agent calls RenderPreview for that view
3. Agent sees the rendered preview image
4. If issues: edit code → RenderPreview again
5. Repeat until correct
```

**ExecuteSnippet — Swift REPL:**

Run arbitrary Swift code in the Xcode context. Useful for querying project state, testing expressions, or running one-off scripts.

**DocumentationSearch:**

Search Apple's developer documentation and WWDC session transcripts directly from the agent. Useful for finding the right API for accessibility modifiers, view styles, etc.

**Limitations:**
- Requires Xcode 26.3 (RC released Feb 3, 2026)
- Global MCP configs are ignored — must configure per-project
- Shell environment is sandboxed (no Homebrew/Node.js paths)
- `RenderPreview` only works for views that have SwiftUI Preview providers defined

### macos-ui-automation-mcp (install from GitHub)

Described as "Playwright for native Mac apps." An MCP server that enables Claude to interact with native macOS applications through accessibility APIs. Built in Python using PyObjC.

**URL:** [github.com/mb-dev/macos-ui-automation-mcp](https://github.com/mb-dev/macos-ui-automation-mcp)

**Install:**

```bash
git clone https://github.com/mb-dev/macos-ui-automation-mcp.git
cd macos-ui-automation-mcp
pip install -r requirements.txt
```

Add to MCP config:

```json
{
  "mcpServers": {
    "macos-ui": {
      "command": "python",
      "args": ["/path/to/macos-ui-automation-mcp/server.py"]
    }
  }
}
```

**Key tools:**

| Tool | What it does |
|---|---|
| `list_running_applications` | List all running GUI applications |
| `get_app_overview` | Get the accessibility overview of an app (window titles, main elements) |
| `find_elements` | Find UI elements using JSONPath-style queries against the AX tree |
| `find_elements_in_app` | Scoped element search within a specific app |
| `click_by_accessibility_id` | Click an element by its accessibility identifier |
| `click_at_position` | Click at screen coordinates |
| `type_text_to_element_by_selector` | Type text into a specific element found by selector |
| `check_accessibility_permissions` | Verify the process has Accessibility permission |

**JSONPath query example:**

```json
{
  "app": "Media Muncher",
  "query": "$..[?(@.role=='AXButton' && @.title=='Import')]"
}
```

**When to use over Peekaboo:** This MCP is accessibility-tree-first rather than vision-first. It queries elements by role, title, and identifier without needing screenshots. Better for structural queries ("find all buttons", "read all text fields") than visual inspection.

**Limitations:** Small project (24 stars), limited maintenance. Python + PyObjC dependency adds complexity. Less mature than Peekaboo.

### automation-mcp (install via npm)

Full desktop automation MCP server. Mouse, keyboard, screenshots, window management, screen color analysis, region highlighting.

**URL:** [github.com/ashwwwin/automation-mcp](https://github.com/ashwwwin/automation-mcp) (362 stars)

**Install:**

```bash
npm install -g automation-mcp
```

Add to MCP config:

```json
{
  "mcpServers": {
    "automation": {
      "command": "automation-mcp"
    }
  }
}
```

**Key tools:**

| Category | Tools |
|---|---|
| **Mouse** | `click`, `double_click`, `right_click`, `move_mouse`, `scroll`, `drag` |
| **Keyboard** | `type_text`, `press_key`, `key_combo` (shortcuts like Cmd+S) |
| **Screen** | `screenshot` (full or region), `get_pixel_color`, `find_image_on_screen` (template matching) |
| **Window** | `list_windows`, `focus_window`, `resize_window`, `minimize_window`, `get_window_bounds` |
| **Analysis** | `highlight_region` (draw overlay rectangle on screen for debugging) |

**`find_image_on_screen` — template matching:**

Takes a reference image and finds its location on screen. Useful for finding icons or UI elements that are hard to locate via accessibility tree. Uses OpenCV-style template matching.

**When to use over Peekaboo:** More low-level control. Useful when you need precise pixel-color analysis, template matching, or region highlighting for debugging. Less "smart" than Peekaboo (no `see` with element annotation, no `agent` mode).

### macos-automator-mcp (install via npx)

MCP server for executing AppleScript and JXA scripts on macOS, with a knowledge base of 200+ pre-built automation scripts and fuzzy search.

**URL:** [github.com/steipete/macos-automator-mcp](https://github.com/steipete/macos-automator-mcp)

**Install:**

```json
{
  "mcpServers": {
    "macos-automator": {
      "command": "npx",
      "args": ["@steipete/macos-automator-mcp"]
    }
  }
}
```

**Key tools:**

| Tool | What it does |
|---|---|
| `run_applescript` | Execute an AppleScript string and return the result |
| `run_jxa` | Execute a JavaScript for Automation (JXA) string and return the result |
| `search_scripts` | Fuzzy-search the 200+ built-in script knowledge base |
| `get_script` | Retrieve a specific built-in script by name |

**Built-in script categories:**
- App control (launch, quit, activate, hide)
- Window management (resize, move, fullscreen, minimize)
- Finder operations (get selection, open folders, create files)
- System preferences (dark mode, volume, display brightness)
- Notification Center, Mission Control, Spaces
- Safari, Chrome, Mail, Calendar automation
- Clipboard management
- File dialogs

**When to use:** When you need quick AppleScript/JXA execution without writing the scripts from scratch. The 200+ built-in scripts cover many common macOS automation scenarios. Complements Peekaboo — use this for app-level and system-level automation, Peekaboo for UI-element-level interaction.

**Example — toggle dark mode via MCP:**

```
Tool: run_jxa
Script: "Application('System Events').appearancePreferences.darkMode = !Application('System Events').appearancePreferences.darkMode()"
```

### Hammerspoon (install via Homebrew)

A full macOS automation platform scripted in Lua. Exposes window management, screen capture, UI element inspection, keyboard/mouse control, and application management. Runs as a menu bar daemon with a CLI interface.

**URL:** [hammerspoon.org](https://www.hammerspoon.org/) | [GitHub](https://github.com/Hammerspoon/hammerspoon)

**Install:**

```bash
brew install --cask hammerspoon
```

Then enable the CLI tool. Add to `~/.hammerspoon/init.lua`:

```lua
require("hs.ipc")
```

Install the CLI binary from Hammerspoon preferences or:

```bash
# In Hammerspoon console (or via hs CLI after initial setup)
hs.ipc.cliInstall()
```

**Key modules:**

| Module | Capability |
|---|---|
| `hs.window` | Get/set window position, size, focus, minimize, fullscreen |
| `hs.window.filter` | Dynamic window queries with filtering rules |
| `hs.application` | Launch, find, activate, hide applications |
| `hs.screen` | Get screen dimensions, capture screenshots |
| `hs.screen.mainScreen():shotAsJPG()` | Capture screen as JPEG data |
| `hs.eventtap` | Synthesize keyboard and mouse events |
| `hs.mouse` | Get/set mouse position |
| `hs.axuielement` | Full Accessibility API access (read UI hierarchy, perform actions) |
| `hs.drawing` | Draw overlay annotations on screen |
| `hs.alert` | Show on-screen alerts |
| `hs.timer` | Schedule periodic tasks |
| `hs.task` | Run shell commands asynchronously |

**CLI usage (requires Hammerspoon running):**

```bash
# Get focused window title
hs -c 'hs.window.focusedWindow():title()'

# Get window frame (position + size)
hs -c 'hs.window.focusedWindow():frame()'

# Find a specific app's window
hs -c 'hs.application.find("Media Muncher"):mainWindow():frame()'

# Take a screenshot
hs -c 'hs.screen.mainScreen():shotAsJPG("/tmp/hs_screenshot.jpg")'

# Send keyboard shortcut
hs -c 'hs.eventtap.keyStroke({"cmd"}, "a")'

# Move mouse
hs -c 'hs.mouse.absolutePosition({x=400, y=300})'

# Resize a window
hs -c 'hs.application.find("Media Muncher"):mainWindow():setFrame({x=100, y=100, w=1200, h=800})'

# Read accessibility element info
hs -c '
local app = hs.application.find("Media Muncher")
local axApp = hs.axuielement.applicationElement(app)
local children = axApp:attributeValue("AXChildren")
for _, child in ipairs(children) do
    print(child:attributeValue("AXRole"), child:attributeValue("AXTitle"))
end
'

# Click an element by finding it in the AX tree
hs -c '
local app = hs.application.find("Media Muncher")
local axApp = hs.axuielement.applicationElement(app)
-- Search for Import button
local function findButton(element, title)
    if element:attributeValue("AXRole") == "AXButton" and element:attributeValue("AXTitle") == title then
        return element
    end
    local children = element:attributeValue("AXChildren") or {}
    for _, child in ipairs(children) do
        local result = findButton(child, title)
        if result then return result end
    end
end
local btn = findButton(axApp, "Import")
if btn then btn:performAction("AXPress") end
'
```

**When to use:** Hammerspoon is the most powerful all-in-one tool if you're willing to have it running as a daemon. The `hs.axuielement` module gives complete AX API access from Lua, and the CLI makes it scriptable from Claude Code's Bash tool. Good for complex automation sequences that combine window management, AX queries, and input simulation in a single script.

**Limitations:**
- Requires installing and running a menu bar daemon
- Lua scripting language adds a learning curve
- Initial `init.lua` setup required
- The `hs` CLI requires Hammerspoon to be running

### XCUITest (built into Xcode)

Apple's native UI testing framework. Launches the app in a test harness, interacts with UI elements via accessibility queries, captures screenshots, and reports results. Tests are written in Swift and run via `xcodebuild test`.

**Setup:**

XCUITest requires a UI test target in the Xcode project. If one doesn't exist:

1. In Xcode: File > New > Target > UI Testing Bundle
2. This creates a `Media MuncherUITests` group with a test file

**Writing XCUITests:**

```swift
import XCTest

final class MediaMuncherUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testMainWindowExists() throws {
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func testImportButtonExistsAndDisabledWithoutVolume() throws {
        let importButton = app.buttons["Import"]
        XCTAssertTrue(importButton.exists, "Import button should exist")
        XCTAssertFalse(importButton.isEnabled, "Import should be disabled without volume")
    }

    func testSettingsOpensAndCloses() throws {
        // Open settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)

        // Verify settings panel appeared
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 2))

        // Close settings
        app.typeKey("w", modifierFlags: .command)
    }

    func testFileListShowsAfterScan() throws {
        // This would require a connected volume or mock — shown for structure
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(table.cells.count, 0)
    }

    func testScreenshotCapture() throws {
        // Capture and attach a screenshot to the test results
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Main Window"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAccessibilityAudit() throws {
        // Built-in accessibility audit (Xcode 15+)
        try app.performAccessibilityAudit(for: [
            .dynamicType,
            .contrast,
            .elementDetection,
            .hitRegion,
            .sufficientElementDescription,
            .textClipped,
            .trait
        ])
    }

    func testDumpAccessibilityHierarchy() throws {
        // Print the entire accessibility tree (visible in test logs)
        print(app.debugDescription)
    }
}
```

**Running UI tests from CLI:**

```bash
# Run all UI tests
xcodebuild -scheme "Media Muncher" -destination 'platform=macOS' test

# Run a specific UI test
xcodebuild -scheme "Media Muncher" -destination 'platform=macOS' \
  -only-testing:"Media MuncherUITests/MediaMuncherUITests/testImportButtonExistsAndDisabledWithoutVolume" test

# Run with a specific result bundle for screenshot extraction
xcodebuild -scheme "Media Muncher" -destination 'platform=macOS' \
  -resultBundlePath ./UITestResults.xcresult test
```

**Extracting screenshots from test results:**

```bash
# List attachments in the result bundle
xcrun xcresulttool get test-results tests --path ./UITestResults.xcresult

# Export all attachments (screenshots) to a directory
xcrun xcresulttool export attachments --path ./UITestResults.xcresult --output-path ./Screenshots
```

Claude Code can then read the extracted screenshot images.

**Key XCUITest query methods:**

| Query | Usage |
|---|---|
| `app.buttons["Import"]` | Find button by accessibility label |
| `app.staticTexts["No files found"]` | Find static text |
| `app.tables.firstMatch.cells` | Find all table cells |
| `app.windows.count` | Count open windows |
| `element.exists` | Check if element exists |
| `element.isEnabled` | Check if element is interactable |
| `element.waitForExistence(timeout: 5)` | Wait for element to appear |
| `element.tap()` / `element.click()` | Interact with element |
| `app.typeKey("a", modifierFlags: .command)` | Keyboard shortcut |
| `app.debugDescription` | Full accessibility tree as text |
| `app.performAccessibilityAudit(for:)` | Built-in a11y audit (Xcode 15+) |

**When to use:** For formal, repeatable UI tests that run in CI/CD. XCUITests live in the Xcode project, run deterministically, and integrate with test reporting. Use them for critical user flows that must not regress. The `performAccessibilityAudit` method is particularly valuable — it's Apple's own accessibility checker.

**Limitations:**
- Tests must be written in Swift and added to the Xcode project
- App is launched in a test harness, which may behave slightly differently from a normal launch
- System dialogs (NSOpenPanel, NSSavePanel) are difficult to interact with
- Cannot test states that depend on external hardware (USB volumes)
- Slower feedback loop than screenshot-based approaches (must build test target + launch app)

### swift-snapshot-testing (SPM dependency)

Visual regression testing library for SwiftUI views by Point-Free. Renders views in-process, captures reference images, and fails tests when the UI changes unexpectedly. No app launch required.

**URL:** [github.com/pointfreeco/swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

**Install:**

Add to `Package.swift` or via Xcode's SPM integration:

```swift
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
```

Add to the test target's dependencies:

```swift
.testTarget(
    name: "Media MuncherTests",
    dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

**Writing snapshot tests:**

```swift
import XCTest
import SnapshotTesting
@testable import Media_Muncher

final class ViewSnapshotTests: XCTestCase {

    func testMainContentView() {
        // Create the view with test data
        let view = ContentView()
            .frame(width: 1024, height: 768)

        // Wrap in a hosting controller for macOS
        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)

        // Assert snapshot matches reference (creates reference on first run)
        assertSnapshot(of: vc, as: .image)
    }

    func testFileListRow() {
        let file = TestDataFactory.createTestFile(
            name: "IMG_0001.jpg",
            mediaType: .image,
            date: Date(),
            size: 1_024_000
        )
        let row = MediaFileCellView(file: file)
            .frame(width: 600, height: 80)

        let vc = NSHostingController(rootView: row)
        vc.view.frame = CGRect(x: 0, y: 0, width: 600, height: 80)

        assertSnapshot(of: vc, as: .image)
    }

    func testSettingsPanel() {
        let settings = SettingsView()
            .frame(width: 500, height: 400)

        let vc = NSHostingController(rootView: settings)
        vc.view.frame = CGRect(x: 0, y: 0, width: 500, height: 400)

        assertSnapshot(of: vc, as: .image)
    }

    func testEmptyState() {
        let view = ContentView()  // with no volumes/files
            .frame(width: 1024, height: 768)

        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)

        assertSnapshot(of: vc, as: .image)
    }

    func testDarkMode() {
        let view = ContentView()
            .frame(width: 1024, height: 768)
            .environment(\.colorScheme, .dark)

        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)

        assertSnapshot(of: vc, as: .image, named: "dark")
    }

    // Text-based structural snapshot (no pixel comparison)
    func testAccessibilityTree() {
        let view = ContentView()
        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)

        assertSnapshot(of: vc, as: .recursiveDescription(on: .init()))
    }
}
```

**How it works:**

1. First run: no reference image exists → test records the snapshot as the reference and fails with "No reference was found on disk. Automatically recorded snapshot."
2. Subsequent runs: snapshot is compared pixel-by-pixel to the reference. If different → test fails with a diff image.
3. Reference images are stored as `__Snapshots__/<TestClassName>/<testMethodName>.png` next to the test file.
4. Commit reference images to git for team/CI comparison.

**Snapshot strategies:**

| Strategy | What it captures |
|---|---|
| `.image` | Pixel-accurate PNG rendering of the view |
| `.image(precision: 0.98)` | Allow 2% pixel variance (for antialiasing differences) |
| `.recursiveDescription(on:)` | Text-based view hierarchy dump (no rendering) |
| `.dump` | Swift Mirror-based property dump |

**LLM integration:**

Claude Code can read the reference PNG files directly (they're committed to the repo). When a snapshot test fails, Claude can:
1. Read the reference image (`__Snapshots__/ViewSnapshotTests/testMainContentView.png`)
2. Read the failure diff image (in the test output directory)
3. Visually compare and determine if the change was intentional
4. Update the reference image if the change is expected: delete the old snapshot and re-run the test

**When to use:** For visual regression testing of individual SwiftUI views without launching the app. Fast (in-process rendering), deterministic, CI-friendly. Best for views with stable layouts that should not change unintentionally.

**Limitations:**
- Views with heavy dependency injection (environment objects, injected services) may not render correctly in isolation
- Pixel-perfect comparison means any change (even font rendering differences across macOS versions) causes failures — use `precision` parameter to allow tolerance
- Does not test runtime behavior (animations, state changes, user interaction)
- Reference images can be large if testing at Retina resolution
- macOS and iOS render slightly differently, so snapshots are platform-specific

### ViewInspector (SPM dependency)

Runtime introspection and unit testing library for SwiftUI views. Traverses the view hierarchy programmatically to read properties, find elements, and trigger actions — without rendering.

**URL:** [github.com/nalexn/ViewInspector](https://github.com/nalexn/ViewInspector)

**Install:**

Add to `Package.swift` or via Xcode's SPM integration:

```swift
.package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.0")
```

Add to the test target:

```swift
.testTarget(
    name: "Media MuncherTests",
    dependencies: [
        .product(name: "ViewInspector", package: "ViewInspector")
    ]
)
```

**Writing ViewInspector tests:**

```swift
import XCTest
import ViewInspector
@testable import Media_Muncher

// Make views inspectable
extension ContentView: Inspectable {}
extension MediaFileCellView: Inspectable {}
extension SettingsView: Inspectable {}

final class ViewStructureTests: XCTestCase {

    func testImportButtonExists() throws {
        let sut = ContentView()
        let button = try sut.inspect().find(button: "Import")
        XCTAssertNotNil(button)
    }

    func testFileListRowShowsFilename() throws {
        let file = TestDataFactory.createTestFile(name: "IMG_0001.jpg")
        let sut = MediaFileCellView(file: file)
        let text = try sut.inspect().find(text: "IMG_0001.jpg")
        XCTAssertEqual(try text.string(), "IMG_0001.jpg")
    }

    func testSettingsHasAllToggles() throws {
        let sut = SettingsView()
        // Find toggles by their labels
        _ = try sut.inspect().find(ViewType.Toggle.self, containing: "Organize by date")
        _ = try sut.inspect().find(ViewType.Toggle.self, containing: "Rename by date")
        _ = try sut.inspect().find(ViewType.Toggle.self, containing: "Delete originals")
    }

    func testFileStatusDisplaysCorrectly() throws {
        var file = TestDataFactory.createTestFile(name: "test.jpg")
        file.status = .imported

        let sut = MediaFileCellView(file: file)
        // Check that the status is reflected somewhere in the view
        _ = try sut.inspect().find(text: "imported")
    }

    func testButtonTap() throws {
        var tapped = false
        let sut = Button("Import") { tapped = true }
        try sut.inspect().button().tap()
        XCTAssertTrue(tapped)
    }
}
```

**Key inspection methods:**

| Method | What it does |
|---|---|
| `.inspect()` | Start inspecting a view |
| `.find(button: "Label")` | Find a button by its label text |
| `.find(text: "Value")` | Find a Text view by its string |
| `.find(ViewType.Toggle.self)` | Find the first Toggle |
| `.find(ViewType.List.self)` | Find the first List |
| `.find(ViewType.Image.self)` | Find the first Image |
| `.button().tap()` | Simulate tapping a button |
| `.toggle().tap()` | Simulate toggling a Toggle |
| `.textField().setInput("text")` | Type into a TextField |
| `.string()` | Extract text content from a Text view |
| `.isDisabled()` | Check if a view is disabled |
| `.accessibilityLabel()` | Read the accessibility label |
| `.accessibilityValue()` | Read the accessibility value |

**When to use:** For fast, deterministic unit tests of view structure. Tests run in milliseconds with no rendering or app launch. Good for verifying that views contain expected elements, that accessibility labels are set, and that user interactions trigger the right callbacks.

**Complements snapshot testing:** ViewInspector tests structure (does button X exist?), snapshot testing tests appearance (does it look right?). Together they provide comprehensive view coverage.

**Limitations:**
- Views must conform to `Inspectable` protocol (a one-liner per view)
- Complex view hierarchies with many layers of abstraction can be difficult to traverse
- Cannot test visual appearance — only structural properties
- Some SwiftUI features (custom layouts, GeometryReader effects) are not fully introspectable
- Asynchronous state changes require special handling with `ViewHosting`

---

## Workflows

### 1. Visual Bug Detection

**Goal:** Capture screenshots of the running app and use Claude's vision to identify visual defects.

**What it catches:**
- Layout issues — overlapping elements, uneven spacing, misaligned baselines
- Dark mode problems — text invisible against background, icons that don't adapt, hard-coded colors
- Truncated text — long filenames, paths, or status messages clipped by containers
- State indicator bugs — progress bars showing impossible values, disabled buttons that should be enabled
- Missing or broken images — thumbnails that didn't load, placeholder icons still visible
- Inconsistent styling — a button that looks different from other buttons of the same type

**Workflow:**

```
1. Launch app, navigate to target state
2. Capture screenshot
   screencapture -x -l<windowid> /tmp/state.png
3. Read screenshot with Claude vision
4. Prompt: "Examine this screenshot of a macOS media import app.
   Check for: layout issues, truncated text, misaligned elements,
   inconsistent styling, contrast problems, anything that looks wrong."
5. (Optional) Toggle dark mode and repeat:
   osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'
   screencapture -x -l<windowid> /tmp/dark.png
6. Compare light vs dark screenshots for issues
```

**Media Muncher specifics to check:**
- File list with very long filenames (do they truncate gracefully?)
- Empty state when no volume is connected (is it helpful?)
- Import progress with many files (does the progress bar render correctly?)
- Settings panel (are all controls aligned and labeled?)
- Sidebar volume list with many volumes (scrolling, selection highlight)
- Error banners (are they visible and readable?)
- Thumbnail grid with mixed file types (consistent sizing?)

**Dark mode checklist:**

```
1. Capture in light mode: screencapture -x -l<wid> /tmp/light.png
2. Toggle: osascript -l JavaScript -e 'Application("System Events").appearancePreferences.darkMode = true'
3. Wait for redraw: sleep 1
4. Capture in dark mode: screencapture -x -l<wid> /tmp/dark.png
5. Toggle back: osascript -l JavaScript -e 'Application("System Events").appearancePreferences.darkMode = false'
6. Read both images and compare
```

**Limitations:**
- Claude's vision is not pixel-accurate — it cannot measure exact pixel distances, so "is this margin 12px or 16px?" is unreliable
- Cannot detect animation bugs or transitions (only static frames)
- Screenshots may include system UI elements (menu bar clock) that are irrelevant

---

### 2. Exploratory Testing

**Goal:** Systematically explore every reachable UI state, interact with every control, and document findings — including crashes, unexpected behavior, and dead ends.

**What it catches:**
- Buttons that don't do anything or do the wrong thing
- States that have no way out (dead ends)
- Missing validation (e.g., can you start an import with no destination set?)
- Crash-inducing interactions
- UI that becomes unresponsive
- Missing error handling for edge cases
- Controls that should be disabled but aren't (or vice versa)

**Workflow:**

```
Phase 1: Discover what's on screen
  → Dump AX tree to understand all interactive elements
  → Take screenshot for visual context

Phase 2: Plan exploration
  → LLM reasons about the UI structure and generates an exploration plan
  → Prioritizes: critical paths first, then edge cases

Phase 3: Execute and observe (for each action)
  a. Screenshot before
  b. Perform action (click/type/keyboard shortcut)
  c. Wait for UI to settle
  d. Screenshot after
  e. Dump AX tree again
  f. Analyze: "Did something unexpected happen?"

Phase 4: Report findings
  → Structured report of every state visited, action taken, anomaly found
```

**Concrete exploration for Media Muncher:**

```bash
# Step 1: Launch and get initial state
open -a "Media Muncher"
sleep 2

# Step 2: Dump the UI tree
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        entire contents of window 1
    end tell
end tell'

# Step 3: Screenshot the initial state
screencapture -x -l<wid> /tmp/explore_01_initial.png

# Step 4: Try each interactive element...
# (LLM decides order based on AX tree analysis)

# Example: Click a sidebar item
osascript -e '
tell application "System Events"
    tell process "Media Muncher"
        click row 1 of table 1 of scroll area 1 of splitter group 1 of window 1
    end tell
end tell'
sleep 1
screencapture -x -l<wid> /tmp/explore_02_after_sidebar_click.png

# Example: Try keyboard shortcut
osascript -e 'tell application "System Events" to keystroke "," using command down'
sleep 1
screencapture -x -l<wid> /tmp/explore_03_settings.png
```

**Edge cases the LLM should invent (domain-specific):**
- What happens with zero files on a volume?
- What if the destination folder is deleted while the app is running?
- What if you click Import twice rapidly?
- What if you change the destination while import is in progress?
- What happens when all files are duplicates?
- What if a file is locked/read-only on the source volume?
- What happens at minimum window size?
- Does Cmd+A select all files? Does Cmd+Shift+A deselect?

**Using Peekaboo for exploration:**

If the Peekaboo MCP is configured, exploration becomes simpler:

```
1. Peekaboo `see` → get annotated screenshot with element IDs
2. Claude examines the annotated screenshot
3. Claude calls Peekaboo `click` on element N
4. Peekaboo `see` again → observe result
5. Repeat until all elements explored
```

The `agent` tool can even chain this: "Explore all buttons and menus in Media Muncher, taking a screenshot after each interaction."

**Limitations:**
- System dialogs (NSOpenPanel, NSSavePanel) are difficult to automate
- Timing — knowing when the UI has fully settled after an action requires polling or delays
- Hardware-dependent states (volume connection) cannot be simulated from software
- Long explorations are expensive in API tokens (each screenshot costs ~1k tokens)

---

### 3. Regression Testing

**Goal:** Before and after a code change, capture screenshots of significant UI states and compare them, flagging unintended visual changes.

**What it catches:**
- UI elements that moved, disappeared, or changed appearance after a code change
- Text that changed unintentionally
- Buttons or controls that became disabled/enabled when they shouldn't have
- Layout shifts from SwiftUI view hierarchy changes
- Style changes from modifier order changes

**Three complementary approaches:**

#### Approach A: LLM Visual Diff

Present Claude with before/after screenshots and ask it to identify differences in context of the code change.

```
1. Before the change:
   - Build and launch the app
   - Drive to each significant state
   - Capture screenshot for each state
   - Store as baseline

2. After the change:
   - Build and launch the app
   - Drive to the same states in the same order
   - Capture screenshot for each state

3. For each state, show Claude both images:
   "This is the UI before my change (image 1) and after (image 2).
    My change was: [description from git diff].
    Identify any visual differences. Classify each as:
    - EXPECTED (related to the change)
    - UNEXPECTED (possible regression)"
```

#### Approach B: Pixel Diff + LLM Interpretation

Use ImageMagick for precise pixel comparison, then have Claude interpret the result.

```bash
# Create visual diff
compare /tmp/baseline/state1.png /tmp/current/state1.png -compose src /tmp/diff/state1.png

# Get numerical difference count
DIFF_PIXELS=$(compare -metric AE /tmp/baseline/state1.png /tmp/current/state1.png null: 2>&1)
echo "Changed pixels: $DIFF_PIXELS"
```

Then show Claude the diff image: "Red areas are pixel changes. Are these expected?"

This is more precise than pure visual comparison — it catches single-pixel changes the LLM's vision might miss.

#### Approach C: Structural Diff via AX Tree

Compare accessibility tree dumps textually. Catches structural changes without depending on visual rendering.

```bash
# Before change
osascript -e 'tell application "System Events" to entire contents of window 1 of process "Media Muncher"' > /tmp/baseline_ax.txt

# After change
osascript -e 'tell application "System Events" to entire contents of window 1 of process "Media Muncher"' > /tmp/current_ax.txt

# Text diff
diff /tmp/baseline_ax.txt /tmp/current_ax.txt
```

This catches: missing elements, changed labels, altered hierarchy, changed enabled/disabled states. It is more reliable than visual comparison for structural regressions and doesn't depend on rendering.

**Best practice: combine all three.** AX tree diff catches structural changes. Pixel diff catches visual changes. Claude interprets both in context of the code change.

**Defining baseline states for Media Muncher:**

| State | How to reach | What to capture |
|---|---|---|
| Empty (no volume) | Fresh launch, no USB connected | Main window |
| Volume connected, scanning | Connect USB, wait for scan start | Main window with progress |
| Files listed | Wait for scan to complete | File list, sidebar |
| Files selected | Cmd+A after scan | Selection state |
| Import in progress | Click Import | Progress bar, file statuses |
| Import complete | Wait for import | Completion state |
| Settings open | Cmd+, | Settings panel |
| Error state | Import to read-only destination | Error banner |

**Limitations:**
- Requires the app to reach the exact same states both times (non-trivial for states that depend on external conditions)
- Dynamic content (timestamps, file counts) causes spurious diffs — test fixtures help
- Window position and system UI elements (clock) cause false positives — crop to app content area
- Pixel diffs are meaningless if the window size differs by even 1px between captures

---

### 4. Accessibility Auditing

**Goal:** Read the complete accessibility tree of the application and audit it against macOS accessibility best practices, WCAG guidelines, and Apple's Human Interface Guidelines.

**What it catches:**
- Interactive elements with no label (VoiceOver says "button" with no context)
- Missing roles on custom SwiftUI views
- Keyboard navigation gaps (elements unreachable via Tab)
- Illogical tab order
- Redundant or unhelpful labels ("button" as a button's label)
- Missing group descriptions for lists and tables
- Dynamic content not announced to VoiceOver (import progress updates)
- Contrast issues (text hard to read against background)

**This is the highest-value, lowest-effort workflow.** Most indie macOS apps have significant accessibility gaps, and a single audit finds many actionable issues.

**Workflow:**

```
Step 1: Dump the full AX tree

  osascript -e '
  tell application "System Events"
      tell process "Media Muncher"
          set allElements to entire contents of window 1
          set output to {}
          repeat with elem in allElements
              try
                  set elemInfo to (class of elem as text) & " | " & ¬
                      (role of elem as text) & " | " & ¬
                      (description of elem as text) & " | " & ¬
                      (name of elem as text) & " | " & ¬
                      (value of elem as text)
                  set end of output to elemInfo
              end try
          end repeat
          return output
      end tell
  end tell'

  Or use the Swift script from the Tools Reference section above for a structured tree dump.
  Or use AXorcist for JSON output:
    echo '{"command":"query","application":"Media Muncher",
    "locator":{"criteria":[{"attribute":"AXRole","value":"*","match":"contains"}]}}' | axorc --stdin

Step 2: Feed the AX tree to Claude with audit instructions

  "Audit this accessibility tree for macOS VoiceOver compatibility.
   Check for:
   1. Interactive elements (buttons, toggles, text fields) without descriptive labels
   2. Images without alt text / accessibility descriptions
   3. Lists and tables without group descriptions
   4. Custom controls missing standard roles
   5. Elements that should be focusable but aren't in the tab order
   6. Redundant labels (e.g., 'button' on a button)
   7. Elements that should announce state changes (progress, errors)"

Step 3: Test keyboard navigation

  # Simulate Tab key presses and check what gains focus
  osascript -e '
  tell application "System Events"
      tell process "Media Muncher"
          set focused to focused UI element of window 1
          keystroke tab
          delay 0.3
          set focused2 to focused UI element of window 1
          return {class of focused, description of focused, class of focused2, description of focused2}
      end tell
  end tell'

  Repeat to trace the full tab order through the app.

Step 4: Simulate VoiceOver announcements

  For each element, the LLM predicts what VoiceOver would announce based on
  role + label + value and checks if it makes sense:
  - "Import, button" → Good
  - "image" → Bad (no description for the thumbnail)
  - "3 of 47, row" → Unclear without table description
```

**SwiftUI accessibility improvements to look for:**

The audit will likely recommend adding modifiers like:

```swift
// For buttons with only icons
Button(action: import) {
    Image(systemName: "square.and.arrow.down")
}
.accessibilityLabel("Import selected files")

// For file list rows
HStack { ... }
.accessibilityElement(children: .combine)
.accessibilityLabel("\(file.sourceName), \(file.status.description)")

// For progress indicators
ProgressView(value: progress)
.accessibilityValue("\(Int(progress * 100)) percent complete")

// For the volume sidebar
List(volumes) { volume in ... }
.accessibilityLabel("Connected volumes")
```

**Limitations:**
- The LLM cannot actually hear VoiceOver — it infers announcements from the AX tree
- Some issues only appear during dynamic interactions (focus trapping in sheets)
- Contrast ratio calculation needs precise color sampling, which vision alone cannot provide
- SwiftUI provides reasonable default accessibility, so findings may be more subtle

---

### 5. User Flow Simulation

**Goal:** Drive the application through complete, realistic user workflows end-to-end, verifying that each step behaves correctly.

**What it catches:**
- Multi-step sequences that break (works in isolation but fails as a flow)
- State that doesn't reset properly between operations
- Race conditions from rapid user actions
- Flows that require too many steps (UX friction)
- Missing feedback at transition points ("did my click register?")

**Key flows for Media Muncher:**

#### Flow 1: First-Time User Experience

```
1. Launch Media Muncher (fresh, no prior settings)
2. VERIFY: Empty state is shown with helpful guidance
3. VERIFY: Import button is disabled (no volume, no destination)
4. Open Settings (Cmd+,)
5. Set destination folder to ~/Desktop/ImportTest
6. Close Settings
7. VERIFY: UI reflects destination is set
8. (If volume available) Select volume in sidebar
9. VERIFY: File scanning starts, progress shown
10. Wait for scan completion
11. VERIFY: Files appear in list with thumbnails
12. Select all files (Cmd+A)
13. Click Import
14. VERIFY: Progress bar appears, file statuses update
15. Wait for completion
16. VERIFY: Success state shown
17. VERIFY: Files exist in destination with expected naming
```

#### Flow 2: Duplicate Detection

```
1. Complete Flow 1 (files already imported)
2. Re-scan the same volume
3. VERIFY: Files show as pre-existing (not waiting)
4. VERIFY: Import button reflects nothing new to import
5. Add a new file to the volume (if possible)
6. Re-scan
7. VERIFY: New file shows as waiting, old files as pre-existing
```

#### Flow 3: Settings Changes Mid-Session

```
1. Scan a volume with renameByDate=false
2. VERIFY: Destination paths preserve original filenames
3. Open Settings, enable renameByDate
4. VERIFY: Destination paths recalculate to YYYYMMDD_HHMMSS format
5. Open Settings, enable organizeByDate
6. VERIFY: Destination paths include YYYY/MM/ directory structure
7. Change destination folder
8. VERIFY: All paths recalculate with new root
```

#### Flow 4: Error Recovery

```
1. Set destination to a path that will fail
   (e.g., create read-only directory: mkdir /tmp/readonly && chmod 000 /tmp/readonly)
2. Scan a volume and start import
3. VERIFY: Error is shown clearly to the user
4. VERIFY: App remains functional (not stuck)
5. Change destination to a valid path
6. Retry import
7. VERIFY: Import succeeds
```

**Execution approach:**

Each step translates to one or more tool calls:

```bash
# Step 1: Launch
open -a "Media Muncher"
sleep 2

# Step 2: Capture and verify empty state
screencapture -x -l<wid> /tmp/flow1_step2.png
# → Claude reads image and checks for empty state guidance

# Step 4: Open Settings
osascript -e 'tell application "System Events" to keystroke "," using command down'
sleep 1

# Step 5: Interact with settings panel
# (Use AX tree to find destination folder picker, click it, navigate dialog)
```

**Using Peekaboo for flows:**

```
1. Peekaboo `app` launch "Media Muncher"
2. Peekaboo `see` → observe initial state
3. Peekaboo `hotkey` cmd+, → open settings
4. Peekaboo `see` → find destination picker
5. Peekaboo `click` element N → open folder picker
6. Peekaboo `dialog` navigate → select destination
7. Peekaboo `see` → verify settings changed
...
```

**The key advantage over scripted XCUITests:** The LLM adapts in real-time. If an unexpected dialog appears, it reads the dialog, decides what to do, and continues. If a step fails, it tries to recover. This is closer to how a human tester works.

**Limitations:**
- System file dialogs (NSOpenPanel/NSSavePanel) are challenging to automate reliably
- Permission prompts interrupt flows unpredictably
- Flows requiring actual media files on a volume need test fixtures or real hardware
- Timing is non-deterministic — file copies take variable time, and the LLM must poll or wait

---

### 6. Design System Verification

**Goal:** Check that the application's UI follows consistent design rules across all screens: fonts, colors, spacing, icon styles, and component usage.

**What it catches:**
- Inconsistent padding/margins between similar elements
- Mixed font sizes for the same semantic level (e.g., two different body text sizes)
- Buttons styled differently in different panels
- Icons from different families or weights
- Colors that don't match the system palette
- List rows with inconsistent heights
- Toolbar items at different sizes

**Two complementary approaches:**

#### Approach A: Code-Level Analysis

The LLM reads SwiftUI view files and checks for consistency:

```
1. Read all view files:
   Media Muncher/Views/*.swift

2. Extract all styling modifiers:
   .font(), .padding(), .foregroundColor(), .frame(),
   .cornerRadius(), .shadow(), .background()

3. Group by semantic purpose:
   - Primary buttons: What font, padding, color?
   - List rows: What height, padding, divider style?
   - Section headers: What font, color, spacing?
   - Icons: What size, weight, rendering mode?

4. Flag inconsistencies:
   "View A uses .padding(12) for list rows but View B uses .padding(16)"
   "Two toolbar buttons use different SF Symbol weights"
   "Body text is .font(.body) in the file list but .font(.callout) in settings"
```

This is highly practical — the LLM already has access to the source code.

#### Approach B: Visual Cross-Screen Comparison

Capture every distinct screen/panel and compare visually:

```bash
# Capture main window
screencapture -x -l<wid> /tmp/design_main.png

# Open settings, capture
osascript -e 'tell application "System Events" to keystroke "," using command down'
sleep 1
screencapture -x -l<wid> /tmp/design_settings.png

# Close settings, trigger import to see progress state
osascript -e 'tell application "System Events" to keystroke "w" using command down'
# ... navigate to import state ...
screencapture -x -l<wid> /tmp/design_import.png
```

Then present all screenshots to Claude:

```
"These are three screens from the same macOS app.
 Analyze for design consistency:
 1. Are fonts consistent for similar elements across screens?
 2. Is spacing/padding consistent?
 3. Are button styles consistent?
 4. Are icon sizes and styles consistent?
 5. Does the color palette feel unified?
 6. Are list/table row heights consistent?"
```

#### Approach C: AX Tree Font Analysis

The accessibility tree exposes some styling information:

```bash
# Extract font information from AX tree
osascript -l JavaScript -e '
var se = Application("System Events");
var proc = se.processes["Media Muncher"];
var texts = proc.windows[0].staticTexts();
texts.map(t => ({
    value: t.value(),
    // Font info may be available via AX attributes
    role: t.role(),
    size: t.size()
}));
'
```

**SwiftUI-specific checks for Media Muncher:**
- Are all SF Symbols using the same rendering mode (`.symbolRenderingMode(.hierarchical)` vs `.monochrome`)?
- Are all primary actions using the same button style?
- Is the sidebar using standard `List` with `SidebarListStyle`?
- Are all spacing values from a consistent set (4, 8, 12, 16, 24)?
- Are all colors from the system palette (`.primary`, `.secondary`, `.accentColor`) or custom?
- Are `.frame(maxWidth: .infinity)` usages consistent for full-width elements?

**Limitations:**
- SwiftUI's declarative nature means many styles are implicit (system defaults) — the code analysis may miss these
- Claude cannot measure exact pixel values from screenshots
- System-provided components (toolbars, sidebars) have their own styling the app doesn't control
- Dynamic Type support means font sizes change with user settings

---

### 7. Live Development Feedback Loop

**Goal:** While writing code, the LLM agent builds the app, captures the UI result, and verifies the change looks correct — creating a tight implement→verify→iterate cycle.

**What it enables:**
- The LLM verifies its own UI changes visually, not just syntactically
- Catches layout issues immediately rather than during later QA
- Enables "make it look like X" instructions where the LLM iterates until the visual result matches
- Reduces the need for the developer to manually build, launch, and navigate to check every change

**Workflow:**

```
1. LLM edits a SwiftUI view file
2. Build the project:
   xcodebuild -scheme "Media Muncher" build
3. Launch (or re-launch) the app:
   killall "Media Muncher" 2>/dev/null; open -a "Media Muncher"
   sleep 2
4. Navigate to the affected screen:
   (via osascript or Peekaboo)
5. Capture screenshot:
   screencapture -x -l<wid> /tmp/feedback.png
6. Read the screenshot and analyze:
   "I changed the file list row height from 60 to 80.
    Does this look correct? Is spacing even? Do thumbnails
    still align with text?"
7. If not correct: edit code and repeat from step 2
```

**Example session:**

```
User: "Make the file list rows taller with more space between the thumbnail and the filename"

LLM:
1. Reads MediaFileCellView.swift
2. Increases row height, adjusts spacing
3. Builds: xcodebuild -scheme "Media Muncher" build
4. Launches app, navigates to file list
5. Captures screenshot
6. Analyzes: "Rows are taller. The spacing between thumbnail and filename
   increased from ~8px to ~16px. However, the status icon on the right
   now appears vertically misaligned — it's pushed to the top of the row
   instead of being centered."
7. Fixes the alignment in code
8. Builds again, captures, verifies
9. "Looks correct now. Rows are taller, spacing is even, all elements
   are vertically centered."
```

**Using Peekaboo for the feedback loop:**

```
1. Edit code
2. Build
3. Peekaboo `app` launch "Media Muncher"
4. Peekaboo `see` → annotated screenshot
5. Claude analyzes the annotated view
6. If issues found → edit code → repeat
```

**Using Xcode 26.3's RenderPreview (when available):**

Xcode 26.3 exposes a `RenderPreview` MCP tool that captures SwiftUI Preview images without launching the full app. This is faster than the full build→launch→capture cycle:

```
1. Edit code
2. Call RenderPreview MCP tool for the specific view
3. Claude sees the rendered preview image
4. If issues found → edit code → repeat
```

This is the fastest possible feedback loop because it skips app launch entirely.

**Practical tips:**
- Keep the app window at a consistent size and position between captures for reliable comparison
- Use `osascript` to set a deterministic window frame before each capture:
  ```bash
  osascript -e '
  tell application "System Events"
      tell process "Media Muncher"
          set position of window 1 to {100, 100}
          set size of window 1 to {1200, 800}
      end tell
  end tell'
  ```
- For iterative changes, save sequential screenshots (`/tmp/iter_01.png`, `iter_02.png`) to track progress
- Include the git diff context when asking Claude to verify — it helps distinguish expected vs unexpected changes

**Limitations:**
- Full app build + launch takes ~10-30 seconds per iteration — not instant
- The app must be navigated to the relevant screen, which may require multiple steps
- Cannot see animations or transitions, only static states
- Xcode Previews (when available) are faster but may not render correctly for views with heavy dependency injection
- The feedback loop breaks if the build fails — the LLM must fix build errors before it can verify visually
