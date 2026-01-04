import Cocoa

class CommandRowView: NSTableRowView {
    private var selectionLayer: CAShapeLayer?
    private var currentlySelected = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        selectionLayer = CAShapeLayer()
        // Apple-like selection - accent color with subtle fill
        selectionLayer?.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        selectionLayer?.strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        selectionLayer?.lineWidth = 1.5
        selectionLayer?.opacity = 0
        layer?.addSublayer(selectionLayer!)
    }

    override func layout() {
        super.layout()
        updateSelectionPath()
    }

    private func updateSelectionPath() {
        let selectionRect = bounds.insetBy(dx: 6, dy: 1)
        let path = CGPath(roundedRect: selectionRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        selectionLayer?.path = path
        selectionLayer?.frame = bounds
    }

    override var isSelected: Bool {
        didSet {
            if isSelected != currentlySelected {
                currentlySelected = isSelected
                animateSelection(isSelected)
            }
        }
    }

    private func animateSelection(_ selected: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1))

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = selectionLayer?.opacity
        opacityAnim.toValue = selected ? 1.0 : 0.0
        opacityAnim.duration = 0.2
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        selectionLayer?.add(opacityAnim, forKey: "opacity")
        selectionLayer?.opacity = selected ? 1.0 : 0.0

        // Scale animation for subtle bounce
        if selected {
            let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnim.values = [0.97, 1.01, 1.0]
            scaleAnim.keyTimes = [0, 0.6, 1]
            scaleAnim.duration = 0.25
            selectionLayer?.add(scaleAnim, forKey: "scale")
        }

        CATransaction.commit()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        // Selection handled by layer animation
    }

    override func drawBackground(in dirtyRect: NSRect) {
        // Clean background - no hover effect for minimal look
    }

    override var isEmphasized: Bool {
        get { false }
        set {}
    }
}
