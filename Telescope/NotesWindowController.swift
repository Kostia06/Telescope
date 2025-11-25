import Cocoa

class NotesWindowController: NSWindowController {
    private var notesViewController: NotesViewController!

    init() {
        // Create window with modern glass effect
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Notes"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 500)

        // Modern glass appearance
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        // Smooth animations
        window.animationBehavior = .default

        // Initialize with window
        super.init(window: window)

        // Create and set view controller
        notesViewController = NotesViewController()
        window.contentViewController = notesViewController
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        notesViewController.refreshNotes()
    }

    func selectNote(id: String) {
        notesViewController.selectNote(id: id)
    }
}
