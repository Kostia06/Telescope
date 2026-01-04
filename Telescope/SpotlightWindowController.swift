import Cocoa

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SpotlightWindowController: NSWindowController {
    private var spotlightViewController: SpotlightViewController!
    private let panelWidth: CGFloat = 480
    private let minHeight: CGFloat = 56
    private let maxHeight: CGFloat = 420
    private let searchBarHeight: CGFloat = 56
    private let rowHeight: CGFloat = 48

    init(commandManager: CommandManager) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 56),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: panel)

        setupPanel(panel)
        spotlightViewController = SpotlightViewController(commandManager: commandManager, windowController: self)
        panel.contentViewController = spotlightViewController

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

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.masksToBounds = false

        // Enhanced shadow for notch appearance (only on sides and bottom)
        panel.contentView?.shadow = NSShadow()
        panel.contentView?.layer?.shadowColor = NSColor.black.cgColor
        panel.contentView?.layer?.shadowOpacity = 0.6
        panel.contentView?.layer?.shadowOffset = NSSize(width: 0, height: -12)
        panel.contentView?.layer?.shadowRadius = 32
    }

    func togglePanel() {
        guard let window = window else { return }
        window.isVisible ? hidePanel() : showPanel()
    }

    func showPanel() {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame

        // Final position (centered, 60pt below menu bar)
        let finalFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.maxY - minHeight - 60,
            width: panelWidth,
            height: minHeight
        )

        // Start position (slightly above final position for subtle drop)
        let startFrame = NSRect(
            x: finalFrame.origin.x,
            y: finalFrame.origin.y + 8,
            width: panelWidth,
            height: minHeight
        )

        window.setFrame(startFrame, display: false, animate: false)
        spotlightViewController.focusSearchField()

        window.alphaValue = 0
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        // Smooth spring animation with fade-in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1) // Spring-like bounce
            window.animator().alphaValue = 1
            window.animator().setFrame(finalFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.spotlightViewController.focusSearchField()
        })
    }

    func hidePanel() {
        guard let window = window else { return }

        let currentFrame = window.frame

        // Subtle slide up while fading out
        let hideFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + 6,
            width: currentFrame.width,
            height: currentFrame.height
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1) // Smooth ease-out
            window.animator().alphaValue = 0
            window.animator().setFrame(hideFrame, display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })
    }

    func updateWindowHeight(for resultCount: Int) {
        guard let window = window, window.isVisible, let screen = NSScreen.main else { return }

        let newHeight: CGFloat
        if resultCount == 0 {
            newHeight = minHeight
        } else {
            let resultsHeight = CGFloat(min(resultCount, 8)) * rowHeight + 12
            newHeight = min(searchBarHeight + resultsHeight, maxHeight)
        }

        if abs(window.frame.height - newHeight) < 1 { return }

        let screenFrame = screen.visibleFrame
        let currentFrame = window.frame

        // Keep window anchored at top of its current position (grows downward)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: screenFrame.maxY - newHeight - 60,
            width: panelWidth,
            height: newHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1) // Smooth spring
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }

    func updateWindowHeightManual(height: CGFloat) {
        guard let window = window, window.isVisible, let screen = NSScreen.main else { return }

        let newHeight = min(height, maxHeight)

        if abs(window.frame.height - newHeight) < 1 { return }

        let screenFrame = screen.visibleFrame
        let currentFrame = window.frame

        // Keep window anchored at top of its current position (grows downward)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: screenFrame.maxY - newHeight - 60,
            width: panelWidth,
            height: newHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1) // Smooth spring
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }
}
