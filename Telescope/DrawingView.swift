import Cocoa

enum DrawingShape {
    case freehand
    case line
    case rectangle
    case circle
    case arrow
    case text
    case eraser
    case select
}

enum EraserMode {
    case normal  // Drag to erase paths
    case object  // Tap to delete entire strokes
}

enum DrawingColor: String, CaseIterable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case purple = "Purple"
    case orange = "Orange"
    case black = "Black"
    case white = "White"
    
    var nsColor: NSColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        case .black: return .black
        case .white: return .white
        }
    }
    
    var icon: String {
        return "circle.fill"
    }
}

class DrawingView: NSView {
    private var paths: [DrawingPath] = []
    private var currentPath: DrawingPath?
    private var startPoint: NSPoint?
    private var isDrawing = false
    private var toolbarView: DrawingToolbarView?
    private var textInputField: NSTextField?
    weak var controller: DrawingModeController?

    var currentShape: DrawingShape = .select
    var currentColor: DrawingColor = .red
    var lineWidth: CGFloat = 3.0
    var eraserMode: EraserMode = .normal
    private var eraserRadius: CGFloat = 20.0
    private var highlightedPathIndex: Int?
    private var selectedPathIndices: Set<Int> = []
    private var dragOffsets: [Int: NSPoint] = [:]
    private var selectionRectStart: NSPoint?
    private var selectionRectEnd: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        // Add toolbar
        setupToolbar()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var canBecomeKeyView: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        // If text field is active, let it handle the keys
        if textInputField != nil && event.keyCode != 53 {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 53: // ESC key
            if let textField = textInputField {
                textField.removeFromSuperview()
                textInputField = nil
                window?.makeFirstResponder(self)
            } else {
                controller?.toggleDrawingMode()
            }
        case 8: // C key
            if event.modifierFlags.contains(.command) {
                clear()
            }
        case 32: // U key
            if event.modifierFlags.contains(.command) {
                undo()
            }
        case 14: // E key - toggle eraser mode when eraser is selected
            if currentShape == .eraser {
                didToggleEraserMode()
            }
        default:
            super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle key events properly
        super.flagsChanged(with: event)
    }

    private func setupToolbar() {
        let toolbarHeight: CGFloat = 88
        let toolbarWidth: CGFloat = 1200
        let toolbarX = (bounds.width - toolbarWidth) / 2
        let toolbarY = bounds.height - toolbarHeight - 24

        toolbarView = DrawingToolbarView(frame: NSRect(x: toolbarX, y: toolbarY, width: toolbarWidth, height: toolbarHeight))
        toolbarView?.delegate = self
        addSubview(toolbarView!)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        startPoint = location
        isDrawing = true

        switch currentShape {
        case .select:
            // Select mode: find and select path(s)
            if let pathIndex = findPathAtPoint(location) {
                // Check if cmd/shift key is pressed for multi-select
                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift) {
                    // Toggle selection
                    if selectedPathIndices.contains(pathIndex) {
                        selectedPathIndices.remove(pathIndex)
                        dragOffsets.removeValue(forKey: pathIndex)
                    } else {
                        selectedPathIndices.insert(pathIndex)
                        let path = paths[pathIndex]
                        if !path.points.isEmpty {
                            dragOffsets[pathIndex] = NSPoint(
                                x: location.x - path.points[0].x,
                                y: location.y - path.points[0].y
                            )
                        }
                    }
                } else {
                    // Single selection (or start drag of already selected items)
                    if !selectedPathIndices.contains(pathIndex) {
                        selectedPathIndices = [pathIndex]
                        dragOffsets.removeAll()
                        let path = paths[pathIndex]
                        if !path.points.isEmpty {
                            dragOffsets[pathIndex] = NSPoint(
                                x: location.x - path.points[0].x,
                                y: location.y - path.points[0].y
                            )
                        }
                    } else {
                        // Update drag offsets for all selected paths
                        for index in selectedPathIndices {
                            let path = paths[index]
                            if !path.points.isEmpty {
                                dragOffsets[index] = NSPoint(
                                    x: location.x - path.points[0].x,
                                    y: location.y - path.points[0].y
                                )
                            }
                        }
                    }
                }
            } else {
                // Start selection rectangle
                if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                    selectedPathIndices.removeAll()
                    dragOffsets.removeAll()
                }
                selectionRectStart = location
                selectionRectEnd = location
            }
            needsDisplay = true
            return

        case .eraser:
            if eraserMode == .object {
                // Object mode: delete entire stroke on tap
                if let pathIndex = findPathAtPoint(location) {
                    paths.remove(at: pathIndex)
                    needsDisplay = true
                }
            } else {
                // Normal mode: start erasing
                erasePathsNearPoint(location)
                needsDisplay = true
            }
            return
        case .text:
            showTextInput(at: location)
            return
        case .freehand:
            currentPath = DrawingPath(
                points: [location],
                color: currentColor.nsColor,
                lineWidth: lineWidth,
                shape: .freehand
            )
        case .line, .rectangle, .circle, .arrow:
            currentPath = DrawingPath(
                points: [location, location],
                color: currentColor.nsColor,
                lineWidth: lineWidth,
                shape: currentShape
            )
        }

        needsDisplay = true
    }

    private func showTextInput(at location: NSPoint) {
        let textField = NSTextField(frame: NSRect(x: location.x, y: location.y - 20, width: 200, height: 40))
        textField.font = NSFont.systemFont(ofSize: 18)
        textField.textColor = currentColor.nsColor
        textField.backgroundColor = NSColor.white.withAlphaComponent(0.9)
        textField.isBordered = true
        textField.focusRingType = .none
        textField.placeholderString = "Type text..."
        textField.target = self
        textField.action = #selector(textInputCompleted(_:))

        addSubview(textField)
        window?.makeFirstResponder(textField)
        textInputField = textField
    }

    @objc private func textInputCompleted(_ sender: NSTextField) {
        guard !sender.stringValue.isEmpty else {
            sender.removeFromSuperview()
            textInputField = nil
            window?.makeFirstResponder(self)
            return
        }

        let textPath = DrawingPath(
            points: [NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y + 20)],
            color: currentColor.nsColor,
            lineWidth: lineWidth,
            shape: .text,
            text: sender.stringValue
        )
        paths.append(textPath)

        sender.removeFromSuperview()
        textInputField = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }

        let location = convert(event.locationInWindow, from: nil)

        switch currentShape {
        case .select:
            // Check if dragging selection rectangle
            if selectionRectStart != nil {
                selectionRectEnd = location
                needsDisplay = true
            }
            // Or dragging selected paths
            else if !selectedPathIndices.isEmpty && !dragOffsets.isEmpty {
                for index in selectedPathIndices {
                    if let offset = dragOffsets[index] {
                        let targetPoint = NSPoint(x: location.x - offset.x, y: location.y - offset.y)
                        movePathToPoint(at: index, to: targetPoint)
                    }
                }
                needsDisplay = true
            }
            return

        case .eraser:
            if eraserMode == .normal {
                erasePathsNearPoint(location)
            }
        case .freehand:
            currentPath?.points.append(location)
        case .line, .rectangle, .circle, .arrow:
            guard let startPoint = startPoint else { return }
            currentPath?.points = [startPoint, location]
        case .text:
            break
        }

        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)

        let location = convert(event.locationInWindow, from: nil)

        // Highlight paths in object eraser mode or select mode
        if (currentShape == .eraser && eraserMode == .object) || currentShape == .select {
            highlightedPathIndex = findPathAtPoint(location)
            needsDisplay = true
        } else {
            if highlightedPathIndex != nil {
                highlightedPathIndex = nil
                needsDisplay = true
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        // Handle selection rectangle completion
        if currentShape == .select && selectionRectStart != nil && selectionRectEnd != nil {
            let rect = NSRect(
                x: min(selectionRectStart!.x, selectionRectEnd!.x),
                y: min(selectionRectStart!.y, selectionRectEnd!.y),
                width: abs(selectionRectEnd!.x - selectionRectStart!.x),
                height: abs(selectionRectEnd!.y - selectionRectStart!.y)
            )

            // Find all paths within selection rectangle
            for (index, path) in paths.enumerated() {
                if isPathInRect(path, rect: rect) {
                    selectedPathIndices.insert(index)
                }
            }

            selectionRectStart = nil
            selectionRectEnd = nil
            isDrawing = false
            needsDisplay = true
            return
        }

        // Skip for eraser and select modes
        if currentShape == .eraser || currentShape == .select {
            isDrawing = false
            return
        }

        guard isDrawing, let currentPath = currentPath else {
            isDrawing = false
            return
        }

        paths.append(currentPath)
        self.currentPath = nil
        startPoint = nil
        isDrawing = false
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw all paths
        for (index, path) in paths.enumerated() {
            // Highlight selected paths
            if currentShape == .select && selectedPathIndices.contains(index) {
                NSColor.systemBlue.withAlphaComponent(0.4).setStroke()
                let highlightPath = createBezierPath(for: path)
                highlightPath.lineWidth = path.lineWidth + 6
                highlightPath.stroke()
            }
            // Highlight path if hovering in select mode
            else if currentShape == .select && highlightedPathIndex == index {
                NSColor.systemBlue.withAlphaComponent(0.2).setStroke()
                let highlightPath = createBezierPath(for: path)
                highlightPath.lineWidth = path.lineWidth + 6
                highlightPath.stroke()
            }
            // Highlight path if in object eraser mode
            else if currentShape == .eraser && eraserMode == .object && highlightedPathIndex == index {
                NSColor.systemRed.withAlphaComponent(0.3).setStroke()
                let highlightPath = createBezierPath(for: path)
                highlightPath.lineWidth = path.lineWidth + 6
                highlightPath.stroke()
            }
            drawPath(path)
        }

        // Draw selection rectangle
        if currentShape == .select, let rectStart = selectionRectStart, let rectEnd = selectionRectEnd {
            let selectionRect = NSRect(
                x: min(rectStart.x, rectEnd.x),
                y: min(rectStart.y, rectEnd.y),
                width: abs(rectEnd.x - rectStart.x),
                height: abs(rectEnd.y - rectStart.y)
            )

            NSColor.systemBlue.withAlphaComponent(0.2).setFill()
            NSColor.systemBlue.withAlphaComponent(0.6).setStroke()

            let rectPath = NSBezierPath(rect: selectionRect)
            rectPath.lineWidth = 1.5
            rectPath.fill()
            rectPath.stroke()
        }

        if let currentPath = currentPath {
            drawPath(currentPath)
        }
    }
    
    private func drawPath(_ path: DrawingPath) {
        if path.shape == .text, let text = path.text, path.points.count >= 1 {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: path.color,
                .font: NSFont.systemFont(ofSize: 18)
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            attributedString.draw(at: path.points[0])
            return
        }

        guard path.points.count >= 2 else { return }

        path.color.setStroke()
        path.color.setFill()

        let bezierPath = NSBezierPath()
        bezierPath.lineWidth = path.lineWidth
        bezierPath.lineCapStyle = .round
        bezierPath.lineJoinStyle = .round

        switch path.shape {
        case .freehand:
            bezierPath.move(to: path.points[0])
            for point in path.points.dropFirst() {
                bezierPath.line(to: point)
            }

        case .line:
            bezierPath.move(to: path.points[0])
            bezierPath.line(to: path.points[1])

        case .rectangle:
            let rect = NSRect(
                x: min(path.points[0].x, path.points[1].x),
                y: min(path.points[0].y, path.points[1].y),
                width: abs(path.points[1].x - path.points[0].x),
                height: abs(path.points[1].y - path.points[0].y)
            )
            bezierPath.appendRect(rect)

        case .circle:
            let center = path.points[0]
            let radius = hypot(path.points[1].x - path.points[0].x, path.points[1].y - path.points[0].y)
            bezierPath.appendOval(in: NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        case .arrow:
            drawArrow(from: path.points[0], to: path.points[1], in: bezierPath)

        case .text, .eraser, .select:
            break
        }

        bezierPath.stroke()
    }
    
    private func drawArrow(from start: NSPoint, to end: NSPoint, in path: NSBezierPath) {
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        let arrowPoint1 = NSPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = NSPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        path.move(to: end)
        path.line(to: arrowPoint1)
        path.move(to: end)
        path.line(to: arrowPoint2)
    }

    // MARK: - Selection Methods

    private func movePathToPoint(at index: Int, to targetPoint: NSPoint) {
        guard index < paths.count else { return }

        let path = paths[index]
        guard !path.points.isEmpty else { return }

        // Calculate the delta from the first point
        let oldFirstPoint = path.points[0]
        let deltaX = targetPoint.x - oldFirstPoint.x
        let deltaY = targetPoint.y - oldFirstPoint.y

        // Move all points by the delta
        for i in 0..<path.points.count {
            paths[index].points[i] = NSPoint(
                x: path.points[i].x + deltaX,
                y: path.points[i].y + deltaY
            )
        }
    }

    private func isPathInRect(_ path: DrawingPath, rect: NSRect) -> Bool {
        // Check if any point of the path is inside the rectangle
        for point in path.points {
            if rect.contains(point) {
                return true
            }
        }
        return false
    }

    // MARK: - Eraser Methods

    private func erasePathsNearPoint(_ point: NSPoint) {
        paths.removeAll { path in
            isPathNearPoint(path, point: point, threshold: eraserRadius)
        }
    }

    private func isPathNearPoint(_ path: DrawingPath, point: NSPoint, threshold: CGFloat) -> Bool {
        // For text, check bounding box
        if path.shape == .text, let text = path.text, path.points.count >= 1 {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18)
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = NSRect(
                x: path.points[0].x,
                y: path.points[0].y,
                width: textSize.width,
                height: textSize.height
            )
            return textRect.insetBy(dx: -threshold, dy: -threshold).contains(point)
        }

        // For freehand paths, check if any point is near
        if path.shape == .freehand {
            for pathPoint in path.points {
                let distance = hypot(pathPoint.x - point.x, pathPoint.y - point.y)
                if distance <= threshold {
                    return true
                }
            }
            return false
        }

        // For shapes, check if point is near the shape
        guard path.points.count >= 2 else { return false }

        switch path.shape {
        case .line:
            return distanceToLineSegment(point: point, start: path.points[0], end: path.points[1]) <= threshold

        case .rectangle:
            let rect = NSRect(
                x: min(path.points[0].x, path.points[1].x),
                y: min(path.points[0].y, path.points[1].y),
                width: abs(path.points[1].x - path.points[0].x),
                height: abs(path.points[1].y - path.points[0].y)
            )
            return rect.insetBy(dx: -threshold, dy: -threshold).contains(point)

        case .circle:
            let center = path.points[0]
            let radius = hypot(path.points[1].x - path.points[0].x, path.points[1].y - path.points[0].y)
            let distance = hypot(point.x - center.x, point.y - center.y)
            return abs(distance - radius) <= threshold

        case .arrow:
            return distanceToLineSegment(point: point, start: path.points[0], end: path.points[1]) <= threshold

        default:
            return false
        }
    }

    private func findPathAtPoint(_ point: NSPoint) -> Int? {
        // Search in reverse order (top to bottom)
        for (index, path) in paths.enumerated().reversed() {
            if isPathNearPoint(path, point: point, threshold: 15) {
                return index
            }
        }
        return nil
    }

    private func distanceToLineSegment(point: NSPoint, start: NSPoint, end: NSPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projectionX = start.x + t * dx
        let projectionY = start.y + t * dy

        return hypot(point.x - projectionX, point.y - projectionY)
    }

    private func createBezierPath(for path: DrawingPath) -> NSBezierPath {
        let bezierPath = NSBezierPath()
        bezierPath.lineWidth = path.lineWidth
        bezierPath.lineCapStyle = .round
        bezierPath.lineJoinStyle = .round

        guard path.points.count >= 2 else { return bezierPath }

        switch path.shape {
        case .freehand:
            bezierPath.move(to: path.points[0])
            for point in path.points.dropFirst() {
                bezierPath.line(to: point)
            }

        case .line:
            bezierPath.move(to: path.points[0])
            bezierPath.line(to: path.points[1])

        case .rectangle:
            let rect = NSRect(
                x: min(path.points[0].x, path.points[1].x),
                y: min(path.points[0].y, path.points[1].y),
                width: abs(path.points[1].x - path.points[0].x),
                height: abs(path.points[1].y - path.points[0].y)
            )
            bezierPath.appendRect(rect)

        case .circle:
            let center = path.points[0]
            let radius = hypot(path.points[1].x - path.points[0].x, path.points[1].y - path.points[0].y)
            bezierPath.appendOval(in: NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        case .arrow:
            drawArrow(from: path.points[0], to: path.points[1], in: bezierPath)

        case .text, .eraser, .select:
            break
        }

        return bezierPath
    }
    
    func clear() {
        paths.removeAll()
        needsDisplay = true
    }
    
    func undo() {
        guard !paths.isEmpty else { return }
        paths.removeLast()
        needsDisplay = true
    }
}

class DrawingPath {
    var points: [NSPoint]
    let color: NSColor
    let lineWidth: CGFloat
    let shape: DrawingShape
    let text: String?

    init(points: [NSPoint], color: NSColor, lineWidth: CGFloat, shape: DrawingShape, text: String? = nil) {
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.shape = shape
        self.text = text
    }
}

// MARK: - DrawingToolbarDelegate
protocol DrawingToolbarDelegate: AnyObject {
    func didSelectColor(_ color: DrawingColor)
    func didSelectShape(_ shape: DrawingShape)
    func didTapClear()
    func didTapUndo()
    func didTapExit()
    func didChangeThickness(_ thickness: CGFloat)
    func didToggleEraserMode()
}

extension DrawingView: DrawingToolbarDelegate {
    func didSelectColor(_ color: DrawingColor) {
        currentColor = color
    }

    func didSelectShape(_ shape: DrawingShape) {
        currentShape = shape
        // Reset highlight when changing tools
        highlightedPathIndex = nil
        needsDisplay = true
    }

    func didTapClear() {
        clear()
    }

    func didTapUndo() {
        undo()
    }

    func didTapExit() {
        controller?.toggleDrawingMode()
    }

    func didChangeThickness(_ thickness: CGFloat) {
        lineWidth = thickness
    }

    func didToggleEraserMode() {
        eraserMode = eraserMode == .normal ? .object : .normal
        highlightedPathIndex = nil
        needsDisplay = true
        toolbarView?.updateEraserModeLabel()
    }
}

// MARK: - DrawingToolbarView
class DrawingToolbarView: NSView {
    weak var delegate: DrawingToolbarDelegate?
    private var colorButtons: [NSButton] = []
    private var shapeButtons: [NSButton] = []
    private var selectedColorButton: NSButton?
    private var selectedShapeButton: NSButton?
    private var eraserModeLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupToolbar() {
        wantsLayer = true

        // Use visual effect view for proper macOS aesthetic
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        addSubview(visualEffect)

        // Add subtle shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        layer?.shadowRadius = 12

        // Container for all controls with proper spacing
        let contentView = NSView(frame: NSRect(x: 20, y: 0, width: frame.width - 40, height: frame.height))
        visualEffect.addSubview(contentView)

        let yCenter: CGFloat = frame.height / 2

        // Colors section with improved layout
        var xOffset: CGFloat = 0

        let colorsLabel = NSTextField(labelWithString: "Color")
        colorsLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        colorsLabel.textColor = .secondaryLabelColor
        colorsLabel.frame = NSRect(x: xOffset, y: yCenter + 22, width: 60, height: 14)
        colorsLabel.isBordered = false
        colorsLabel.isEditable = false
        colorsLabel.backgroundColor = .clear
        contentView.addSubview(colorsLabel)

        var colorX: CGFloat = xOffset
        for color in DrawingColor.allCases {
            let button = createColorButton(color: color, x: colorX, y: yCenter - 18)
            colorButtons.append(button)
            contentView.addSubview(button)
            colorX += 38

            if color == .red {
                selectedColorButton = button
                button.layer?.borderWidth = 3
                button.layer?.borderColor = NSColor.white.cgColor
            }
        }

        // Vertical separator
        let separator1 = NSBox(frame: NSRect(x: colorX + 12, y: yCenter - 20, width: 1, height: 40))
        separator1.boxType = .separator
        separator1.fillColor = .separatorColor
        contentView.addSubview(separator1)

        // Shapes section
        xOffset = colorX + 32

        let shapesLabel = NSTextField(labelWithString: "Tool")
        shapesLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        shapesLabel.textColor = .secondaryLabelColor
        shapesLabel.frame = NSRect(x: xOffset, y: yCenter + 22, width: 60, height: 14)
        shapesLabel.isBordered = false
        shapesLabel.isEditable = false
        shapesLabel.backgroundColor = .clear
        contentView.addSubview(shapesLabel)

        let shapes: [(DrawingShape, String)] = [
            (.select, "cursorarrow.click.2"),
            (.freehand, "scribble"),
            (.line, "line.diagonal"),
            (.rectangle, "rectangle"),
            (.circle, "circle"),
            (.arrow, "arrow.right"),
            (.text, "textformat"),
            (.eraser, "eraser")
        ]

        var shapeX: CGFloat = xOffset
        for (shape, icon) in shapes {
            let button = createShapeButton(shape: shape, icon: icon, x: shapeX, y: yCenter - 18)
            shapeButtons.append(button)
            contentView.addSubview(button)
            shapeX += 38

            if shape == .select {
                selectedShapeButton = button
                button.layer?.borderWidth = 2.5
                button.layer?.borderColor = NSColor.controlAccentColor.cgColor
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            }
        }

        // Eraser mode toggle button (only visible when eraser is selected)
        let eraserModeButton = createActionButton(icon: "arrow.triangle.2.circlepath", x: shapeX, y: yCenter - 18, action: #selector(eraserModeToggleTapped))
        eraserModeButton.alphaValue = 0
        eraserModeButton.tag = 999 // Special tag for eraser mode button
        contentView.addSubview(eraserModeButton)

        // Eraser mode label
        let modeLabel = NSTextField(labelWithString: "Normal")
        modeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        modeLabel.textColor = .secondaryLabelColor
        modeLabel.frame = NSRect(x: shapeX - 6, y: yCenter - 32, width: 46, height: 12)
        modeLabel.alignment = .center
        modeLabel.isBordered = false
        modeLabel.isEditable = false
        modeLabel.backgroundColor = .clear
        modeLabel.alphaValue = 0
        eraserModeLabel = modeLabel
        contentView.addSubview(modeLabel)

        shapeX += 38

        // Vertical separator
        let separator2 = NSBox(frame: NSRect(x: shapeX + 12, y: yCenter - 20, width: 1, height: 40))
        separator2.boxType = .separator
        separator2.fillColor = .separatorColor
        contentView.addSubview(separator2)

        // Vertical separator
        let separator3 = NSBox(frame: NSRect(x: shapeX + 12, y: yCenter - 20, width: 1, height: 40))
        separator3.boxType = .separator
        separator3.fillColor = .separatorColor
        contentView.addSubview(separator3)

        // Thickness slider
        xOffset = shapeX + 32

        let thicknessLabel = NSTextField(labelWithString: "Size")
        thicknessLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        thicknessLabel.textColor = .secondaryLabelColor
        thicknessLabel.frame = NSRect(x: xOffset, y: yCenter + 22, width: 60, height: 14)
        thicknessLabel.isBordered = false
        thicknessLabel.isEditable = false
        thicknessLabel.backgroundColor = .clear
        contentView.addSubview(thicknessLabel)

        let slider = NSSlider(frame: NSRect(x: xOffset, y: yCenter - 10, width: 100, height: 20))
        slider.minValue = 1
        slider.maxValue = 10
        slider.doubleValue = 3
        slider.target = self
        slider.action = #selector(thicknessChanged(_:))
        slider.isContinuous = true
        contentView.addSubview(slider)

        // Vertical separator
        xOffset = xOffset + 100 + 20
        let separator4 = NSBox(frame: NSRect(x: xOffset - 8, y: yCenter - 20, width: 1, height: 40))
        separator4.boxType = .separator
        separator4.fillColor = .separatorColor
        contentView.addSubview(separator4)

        // Action buttons
        let undoButton = createActionButton(icon: "arrow.uturn.backward", x: xOffset, y: yCenter - 18, action: #selector(undoTapped))
        contentView.addSubview(undoButton)

        let clearButton = createActionButton(icon: "trash", x: xOffset + 38, y: yCenter - 18, action: #selector(clearTapped))
        contentView.addSubview(clearButton)

        // Exit hint with icon
        let exitHintX = xOffset + 38 + 38 + 24

        let escIcon = NSImageView(frame: NSRect(x: exitHintX, y: yCenter - 8, width: 18, height: 18))
        escIcon.image = NSImage(systemSymbolName: "escape", accessibilityDescription: nil)
        escIcon.contentTintColor = .tertiaryLabelColor
        escIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        contentView.addSubview(escIcon)

        let exitLabel = NSTextField(labelWithString: "to exit")
        exitLabel.font = NSFont.systemFont(ofSize: 11)
        exitLabel.textColor = .tertiaryLabelColor
        exitLabel.frame = NSRect(x: exitHintX + 22, y: yCenter - 7, width: 50, height: 14)
        exitLabel.isBordered = false
        exitLabel.isEditable = false
        exitLabel.backgroundColor = .clear
        contentView.addSubview(exitLabel)
    }

    @objc private func thicknessChanged(_ sender: NSSlider) {
        delegate?.didChangeThickness(CGFloat(sender.doubleValue))
    }

    private func createColorButton(color: DrawingColor, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 34, height: 34))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.layer?.backgroundColor = color.nsColor.cgColor
        button.layer?.cornerRadius = 17
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor.separatorColor.cgColor

        // Add subtle inner shadow effect
        let innerShadow = CALayer()
        innerShadow.frame = button.bounds
        innerShadow.cornerRadius = 17
        innerShadow.shadowColor = NSColor.black.cgColor
        innerShadow.shadowOffset = NSSize(width: 0, height: 1)
        innerShadow.shadowOpacity = 0.2
        innerShadow.shadowRadius = 2

        button.target = self
        button.action = #selector(colorButtonTapped(_:))
        button.tag = DrawingColor.allCases.firstIndex(of: color) ?? 0
        return button
    }

    private func createShapeButton(shape: DrawingShape, icon: String, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 34, height: 34))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1.5
        button.layer?.borderColor = NSColor.separatorColor.cgColor

        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
            button.contentTintColor = .labelColor
        }

        button.target = self
        button.action = #selector(shapeButtonTapped(_:))

        switch shape {
        case .select: button.tag = 0
        case .freehand: button.tag = 1
        case .line: button.tag = 2
        case .rectangle: button.tag = 3
        case .circle: button.tag = 4
        case .arrow: button.tag = 5
        case .text: button.tag = 6
        case .eraser: button.tag = 7
        }

        return button
    }

    private func createActionButton(icon: String, x: CGFloat, y: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 34, height: 34))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1.5
        button.layer?.borderColor = NSColor.separatorColor.cgColor

        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
            button.contentTintColor = .secondaryLabelColor
        }

        button.target = self
        button.action = action
        return button
    }

    @objc private func colorButtonTapped(_ sender: NSButton) {
        // Deselect previous
        selectedColorButton?.layer?.borderWidth = 2
        selectedColorButton?.layer?.borderColor = NSColor.separatorColor.cgColor

        // Select new
        sender.layer?.borderWidth = 3
        sender.layer?.borderColor = NSColor.white.cgColor
        selectedColorButton = sender

        let color = DrawingColor.allCases[sender.tag]
        delegate?.didSelectColor(color)
    }

    @objc private func shapeButtonTapped(_ sender: NSButton) {
        // Deselect previous
        selectedShapeButton?.layer?.borderWidth = 1.5
        selectedShapeButton?.layer?.borderColor = NSColor.separatorColor.cgColor
        selectedShapeButton?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Select new
        sender.layer?.borderWidth = 2.5
        sender.layer?.borderColor = NSColor.controlAccentColor.cgColor
        sender.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        selectedShapeButton = sender

        let shapes: [DrawingShape] = [.select, .freehand, .line, .rectangle, .circle, .arrow, .text, .eraser]
        let shape = shapes[sender.tag]

        // Show/hide eraser mode toggle button and label
        if shape == .eraser {
            // Show eraser mode controls with animation
            if let eraserModeButton = subviews.first(where: { $0.tag == 999 }) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    eraserModeButton.animator().alphaValue = 1
                    eraserModeLabel?.animator().alphaValue = 1
                })
            }
        } else {
            // Hide eraser mode controls with animation
            if let eraserModeButton = subviews.first(where: { $0.tag == 999 }) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    eraserModeButton.animator().alphaValue = 0
                    eraserModeLabel?.animator().alphaValue = 0
                })
            }
        }

        delegate?.didSelectShape(shape)
    }

    @objc private func eraserModeToggleTapped() {
        delegate?.didToggleEraserMode()
    }

    func updateEraserModeLabel() {
        // This will be called from the delegate to update the label
        // We need to get the current eraser mode from the DrawingView
        // For simplicity, we'll cycle the label text
        if let label = eraserModeLabel {
            label.stringValue = label.stringValue == "Normal" ? "Object" : "Normal"
        }
    }

    @objc private func clearTapped() {
        delegate?.didTapClear()
    }

    @objc private func undoTapped() {
        delegate?.didTapUndo()
    }
}