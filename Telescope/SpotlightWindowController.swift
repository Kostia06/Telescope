import Cocoa

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class SpotlightWindowController: NSWindowController {
    private var spotlightViewController: SpotlightViewController!
    
    init(commandManager: CommandManager) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 340),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)
        
        setupPanel(panel)
        spotlightViewController = SpotlightViewController(commandManager: commandManager, windowController: self)
        panel.contentViewController = spotlightViewController
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupPanel(_ panel: NSPanel) {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
    }
    
    func togglePanel() {
        guard let window = window else { return }
        
        if window.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    func showPanel() {
        guard let window = window else { return }
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - window.frame.width / 2
            let y = screenFrame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        spotlightViewController.focusSearchField()
        
        window.alphaValue = 0
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.spotlightViewController.focusSearchField()
        })
    }
    
    func hidePanel() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}
