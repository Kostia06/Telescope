import Cocoa
import HotKey

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKey: HotKey!
    var windowController: SpotlightWindowController!
    var commandManager: CommandManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        commandManager = CommandManager()
        windowController = SpotlightWindowController(commandManager: commandManager)
        registerHotKey()
    }

    func registerHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.command])
        hotKey.keyDownHandler = { [weak self] in
            self?.windowController.togglePanel()
        }
    }
}
