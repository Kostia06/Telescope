import Cocoa
import HotKey

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKey: HotKey!
    var windowController: SpotlightWindowController!
    var commandManager: CommandManager!
    var drawingModeController: DrawingModeController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        drawingModeController = DrawingModeController()
        commandManager = CommandManager(drawingModeController: drawingModeController)
        windowController = SpotlightWindowController(commandManager: commandManager)
        registerHotKey()
    }

    func registerHotKey() {
        hotKey = HotKey(key: .space, modifiers: [.command])
        hotKey.keyDownHandler = { [weak self] in
            self?.windowController.togglePanel()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Prevent Command+Q from quitting the app
        return .terminateCancel
    }
}
