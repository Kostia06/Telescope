import Cocoa
import QuartzCore

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class SpotlightWindowController: NSWindowController {
    private var spotlightViewController: SpotlightViewController!
    private let panelWidth: CGFloat = 420
    private let minHeight: CGFloat = 56
    private let maxHeight: CGFloat = 420
    private let searchBarHeight: CGFloat = 56
    private let rowHeight: CGFloat = 48

    init(commandManager: CommandManager) {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 56),
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

        // Apple-style soft shadow
        panel.contentView?.shadow = NSShadow()
        panel.contentView?.layer?.shadowColor = NSColor.black.cgColor
        panel.contentView?.layer?.shadowOpacity = 0.35
        panel.contentView?.layer?.shadowOffset = NSSize(width: 0, height: -8)
        panel.contentView?.layer?.shadowRadius = 40
    }

    func togglePanel() {
        guard let window = window else { return }
        window.isVisible ? hidePanel() : showPanel()
    }

    func showPanel() {
        guard let window = window, let screen = NSScreen.main else { return }

        let screenFrame = screen.frame

        // Final position - centered horizontally and vertically (slightly above center)
        let finalFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: screenFrame.midY - minHeight / 2 + 100,
            width: panelWidth,
            height: minHeight
        )

        window.setFrame(finalFrame, display: false, animate: false)
        spotlightViewController.resetSearch()

        // Set initial state - scaled down and transparent
        window.alphaValue = 0
        if let layer = window.contentView?.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: finalFrame.width / 2, y: finalFrame.height / 2)
            layer.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        }

        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)

        // Smooth spring animation with scale
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            window.animator().alphaValue = 1
        })

        // Scale animation using Core Animation for smoothness
        if let layer = window.contentView?.layer {
            let scaleAnim = CASpringAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.97
            scaleAnim.toValue = 1.0
            scaleAnim.damping = 18
            scaleAnim.stiffness = 300
            scaleAnim.mass = 0.8
            scaleAnim.duration = scaleAnim.settlingDuration
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "showScale")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.spotlightViewController.focusSearchField()
        }
    }

    func hidePanel() {
        guard let window = window else { return }

        // Scale down animation for clean exit
        if let layer = window.contentView?.layer {
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 0.97
            scaleAnim.duration = 0.15
            scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "hideScale")
        }

        // Fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            // Reset transform for next show
            if let layer = window.contentView?.layer {
                layer.removeAnimation(forKey: "hideScale")
                layer.transform = CATransform3DIdentity
            }
            self?.spotlightViewController.resetSearch()
        })
    }

    func updateWindowHeight(for resultCount: Int) {
        guard let window = window, window.isVisible, let screen = NSScreen.main else { return }

        let newHeight: CGFloat
        if resultCount == 0 {
            newHeight = minHeight
        } else {
            let resultsHeight = CGFloat(min(resultCount, 8)) * rowHeight + 8
            newHeight = min(searchBarHeight + resultsHeight, maxHeight)
        }

        if abs(window.frame.height - newHeight) < 1 { return }

        let screenFrame = screen.frame

        // Keep window centered horizontally, anchor at top (grows downward)
        let baseY = screenFrame.midY + 100
        let newFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: baseY - newHeight / 2,
            width: panelWidth,
            height: newHeight
        )

        // Smooth spring animation for height changes
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }

    func updateWindowHeightManual(height: CGFloat) {
        guard let window = window, window.isVisible, let screen = NSScreen.main else { return }

        let newHeight = min(height, maxHeight)

        if abs(window.frame.height - newHeight) < 1 { return }

        let screenFrame = screen.frame

        // Keep window centered horizontally, anchor at top (grows downward)
        let baseY = screenFrame.midY + 100
        let newFrame = NSRect(
            x: screenFrame.midX - panelWidth / 2,
            y: baseY - newHeight / 2,
            width: panelWidth,
            height: newHeight
        )

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }
}
