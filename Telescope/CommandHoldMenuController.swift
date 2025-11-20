import Cocoa

class CommandHoldMenuController: NSObject {
    private var menuWindow: CommandHoldMenuWindow?

    override init() {
        super.init()
    }

    func startMonitoring() {
        // No longer needed - triggered by HotKey instead
    }

    func stopMonitoring() {
        // No longer needed
    }

    func showMenu() {
        // Don't show if already visible
        guard menuWindow == nil else { return }

        // Get the frontmost app name
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Unknown App"
        let bundleId = frontApp?.bundleIdentifier ?? ""

        // Show only the app name in title
        let title = bundleId == "com.telescope.app" ? "No App Focused" : "\(appName) Commands"

        // Get app menu commands only
        let options = getAvailableOptions()

        // Create and show the menu window
        let window = CommandHoldMenuWindow(options: options, title: title)
        window.makeKeyAndOrderFront(nil)
        menuWindow = window
    }

    func hideMenu() {
        menuWindow?.close()
        menuWindow = nil
    }

    private func getAvailableOptions() -> [CommandOption] {
        var options: [CommandOption] = []

        // Get the frontmost application
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Unknown App"
        let bundleId = frontApp?.bundleIdentifier ?? ""

        let isTelescopeFocused = bundleId == "com.telescope.app"

        // === APP MENU BAR COMMANDS ONLY ===
        if !isTelescopeFocused && !bundleId.isEmpty, let pid = frontApp?.processIdentifier {
            let menuCommands = extractMenuBarCommands(pid: pid, appName: appName)
            options.append(contentsOf: menuCommands)
        } else {
            // If no app is focused or Telescope is focused, show a message
            options.append(CommandOption(
                title: "No Application Focused",
                description: "Focus an application window to see its commands",
                action: {}
            ))
        }

        return options
    }

    private func sendKeyCommand(key: String, app: NSRunningApplication?, withShift: Bool = false, withControl: Bool = false) {
        guard let app = app else { return }

        let script = """
        tell application "System Events"
            tell process "\(app.localizedName ?? "")"
                keystroke "\(key)" using {command down\(withShift ? ", shift down" : "")\(withControl ? ", control down" : "")}
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }

    private func runYabaiCommand(args: [String]) {
        let task = Process()
        task.launchPath = "/usr/local/bin/yabai"
        task.arguments = args
        try? task.run()
    }

    // MARK: - Menu Bar Extraction
    private func extractMenuBarCommands(pid: pid_t, appName: String) -> [CommandOption] {
        var commands: [CommandOption] = []

        // Create AXUIElement for the app
        let app = AXUIElementCreateApplication(pid)

        // Get the menu bar
        var menuBarRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef)

        guard result == .success, let menuBar = menuBarRef else {
            return commands
        }

        // Get menu bar children (File, Edit, View, etc.)
        var childrenRef: AnyObject?
        let childrenResult = AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef)

        guard childrenResult == .success, let children = childrenRef as? [AXUIElement] else {
            return commands
        }

        // Parse each menu
        for menuElement in children {
            if let menuCommands = parseMenu(menuElement, appName: appName, menuPath: []) {
                commands.append(contentsOf: menuCommands)
            }
        }

        return commands
    }

    private func parseMenu(_ element: AXUIElement, appName: String, menuPath: [String]) -> [CommandOption]? {
        var commands: [CommandOption] = []

        // Get the title of this menu
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        guard let title = titleRef as? String, !title.isEmpty else {
            return nil
        }

        // Skip some system menus we don't want
        let skipMenus = ["Apple", "", "Telescope"]
        if skipMenus.contains(title) {
            return nil
        }

        let currentPath = menuPath + [title]

        // Get children of this menu
        var childrenRef: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                // Get the role to determine if it's a menu item or submenu
                var roleRef: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)

                guard let role = roleRef as? String else { continue }

                if role == kAXMenuItemRole as String {
                    // Get menu item title
                    var itemTitleRef: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &itemTitleRef)

                    guard let itemTitle = itemTitleRef as? String, !itemTitle.isEmpty else {
                        continue
                    }

                    // Check if enabled
                    var enabledRef: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabledRef)
                    let isEnabled = (enabledRef as? Bool) ?? true

                    if !isEnabled {
                        continue
                    }

                    // Check if it has a submenu
                    var submenuChildrenRef: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &submenuChildrenRef)

                    if let submenuChildren = submenuChildrenRef as? [AXUIElement], !submenuChildren.isEmpty {
                        // This is a submenu, recurse
                        if let submenuCommands = parseMenu(child, appName: appName, menuPath: currentPath) {
                            commands.append(contentsOf: submenuCommands)
                        }
                    } else {
                        // This is a regular menu item
                        let fullPath = (currentPath + [itemTitle]).joined(separator: " → ")

                        // Get keyboard shortcut if available
                        var shortcutRef: AnyObject?
                        AXUIElementCopyAttributeValue(child, "AXMenuItemCmdChar" as CFString, &shortcutRef)
                        var modifiersRef: AnyObject?
                        AXUIElementCopyAttributeValue(child, "AXMenuItemCmdModifiers" as CFString, &modifiersRef)

                        var shortcutText = ""
                        if let cmdChar = shortcutRef as? String {
                            let modifiers = modifiersRef as? Int ?? 0
                            var shortcutParts: [String] = []

                            if modifiers & (1 << 0) != 0 { shortcutParts.append("⌃") } // Control
                            if modifiers & (1 << 1) != 0 { shortcutParts.append("⌥") } // Option
                            if modifiers & (1 << 2) != 0 { shortcutParts.append("⇧") } // Shift
                            if modifiers & (1 << 3) != 0 { shortcutParts.append("⌘") } // Command

                            shortcutParts.append(cmdChar.uppercased())
                            shortcutText = " (" + shortcutParts.joined() + ")"
                        }

                        commands.append(CommandOption(
                            title: "[\(appName)] \(itemTitle)",
                            description: fullPath + shortcutText,
                            action: { [weak self] in
                                self?.executeMenuItem(child)
                            }
                        ))
                    }
                }
            }
        }

        return commands.isEmpty ? nil : commands
    }

    private func executeMenuItem(_ menuItem: AXUIElement) {
        AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
    }
}

struct CommandOption {
    let title: String
    let description: String
    let action: () -> Void
}

class CommandHoldMenuWindow: NSPanel {
    private var menuView: CommandHoldMenuView!

    init(options: [CommandOption], title: String) {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = min(CGFloat(options.count * 60 + 40), 600)

        let rect = NSRect(
            x: (screenRect.width - windowWidth) / 2,
            y: (screenRect.height - windowHeight) / 2,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        menuView = CommandHoldMenuView(frame: rect, options: options, title: title)
        menuView.onOptionSelected = { [weak self] option in
            option.action()
            self?.close()
        }

        self.contentView = menuView

        // Animate in
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        })
    }

    override var canBecomeKey: Bool {
        return true
    }
}
