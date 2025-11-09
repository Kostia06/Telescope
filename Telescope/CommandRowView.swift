import Cocoa

class CommandRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 8, dy: 1)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)

            // Enhanced selection with gradient effect
            NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
            path.fill()

            // Add subtle border to selection
            NSColor.controlAccentColor.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)

        // Add hover effect
        if isMouseOver && !isSelected {
            let hoverRect = bounds.insetBy(dx: 8, dy: 1)
            let path = NSBezierPath(roundedRect: hoverRect, xRadius: 6, yRadius: 6)
            NSColor.controlAccentColor.withAlphaComponent(0.05).setFill()
            path.fill()
        }
    }

    private var isMouseOver = false {
        didSet {
            setNeedsDisplay(bounds)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseOver = true
    }

    override func mouseExited(with event: NSEvent) {
        isMouseOver = false
    }
    
    override var isEmphasized: Bool {
        get { return false }
        set {}
    }
}
