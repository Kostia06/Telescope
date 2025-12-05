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
    private let minHeight: CGFloat = 68
    private let maxHeight: CGFloat = 600
    private let baseHeight: CGFloat = 100 // Height of search bar + padding
    private let rowHeight: CGFloat = 52 // Height per result row

    init(commandManager: CommandManager) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 120),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        setupPanel(panel)
        spotlightViewController = SpotlightViewController(commandManager: commandManager, windowController: self)
        panel.contentViewController = spotlightViewController

        // Keep window hidden on startup
        panel.alphaValue = 0
        panel.orderOut(nil)
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

        // Ensure content view clips to bounds for proper rounded corners
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.masksToBounds = true
        panel.contentView?.layer?.cornerRadius = 16
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

        // Reset to minimum height
        let newFrame: NSRect
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            newFrame = NSRect(
                x: screenFrame.midX - window.frame.width / 2,
                y: screenFrame.midY - minHeight / 2,
                width: window.frame.width,
                height: minHeight
            )
        } else {
            newFrame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: window.frame.width, height: minHeight)
        }

        window.setFrame(newFrame, display: false, animate: false)

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

    func updateWindowHeight(for resultCount: Int) {
        guard let window = window, window.isVisible else { return }

        let newHeight: CGFloat
        if resultCount == 0 {
            newHeight = minHeight
        } else {
            let calculatedHeight = baseHeight + (CGFloat(resultCount) * rowHeight)
            newHeight = min(max(calculatedHeight, minHeight), maxHeight)
        }

        // Don't animate if already at target height
        if abs(window.frame.height - newHeight) < 1 {
            return
        }

        // Get current screen position
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let newFrame = NSRect(
            x: screenFrame.midX - window.frame.width / 2,
            y: screenFrame.midY - newHeight / 2,
            width: window.frame.width,
            height: newHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }
}
