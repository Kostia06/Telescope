import Cocoa

enum DrawingShape: String {
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
    var fontSize: CGFloat = 18.0
    var eraserMode: EraserMode = .normal
    private var eraserRadius: CGFloat = 20.0
    private var highlightedPathIndex: Int?
    private var selectedPathIndices: Set<Int> = []
    private var dragOffsets: [Int: NSPoint] = [:]
    private var selectionRectStart: NSPoint?
    private var selectionRectEnd: NSPoint?
    private var clearedPathsBackup: [DrawingPath]? = nil  // For undo clear

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

        // Load saved drawings
        loadDrawings()
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
        let toolbarHeight: CGFloat = 52
        let toolbarWidth: CGFloat = 760
        let toolbarX = (bounds.width - toolbarWidth) / 2
        let toolbarY = bounds.height - toolbarHeight - 20

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
                    saveDrawings()
                }
            } else {
                // Normal mode: start erasing
                erasePathsNearPoint(location)
                needsDisplay = true
                saveDrawings()
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
        // Create completely invisible text field - no border, no background, no bezel
        let textField = NSTextField(frame: NSRect(x: location.x, y: location.y, width: 300, height: fontSize + 4))
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        textField.textColor = currentColor.nsColor
        textField.backgroundColor = .clear
        textField.drawsBackground = false
        textField.isBordered = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.placeholderString = ""
        textField.target = self
        textField.action = #selector(textInputCompleted(_:))
        textField.wantsLayer = true
        textField.layer?.backgroundColor = NSColor.clear.cgColor

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

        // Get the text field position directly
        let textPath = DrawingPath(
            points: [NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y)],
            color: currentColor.nsColor,
            lineWidth: lineWidth,
            shape: .text,
            text: sender.stringValue,
            fontSize: fontSize
        )
        paths.append(textPath)

        sender.removeFromSuperview()
        textInputField = nil
        window?.makeFirstResponder(self)

        // Auto-switch to select mode after creating text
        currentShape = .select
        toolbarView?.selectShapeButton(for: .select)

        needsDisplay = true
        saveDrawings() // Save after adding text
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
                // Note: Will save in mouseUp
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

        // Handle moving selected paths
        if currentShape == .select && !selectedPathIndices.isEmpty && !dragOffsets.isEmpty {
            saveDrawings() // Save after moving paths
        }

        // Handle eraser mode save
        if currentShape == .eraser {
            isDrawing = false
            if eraserMode == .normal {
                saveDrawings() // Save after dragging eraser
            }
            return
        }

        // Skip for select mode
        if currentShape == .select {
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
        saveDrawings() // Save after completing a path
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
            let textSize = path.fontSize ?? 18.0
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: path.color,
                .font: NSFont.systemFont(ofSize: textSize, weight: .medium)
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
        // For text, check bounding box with larger hit area
        if path.shape == .text, let text = path.text, path.points.count >= 1 {
            let textSize = path.fontSize ?? 18.0
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: textSize, weight: .medium)
            ]
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let size = attributedString.size()
            let textRect = NSRect(
                x: path.points[0].x,
                y: path.points[0].y,
                width: size.width,
                height: size.height
            )
            // Expand hit area significantly for easier selection
            let expandedRect = textRect.insetBy(dx: -threshold * 2, dy: -threshold * 2)
            return expandedRect.contains(point)
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
        // Backup paths before clearing so we can undo
        clearedPathsBackup = paths
        paths.removeAll()
        needsDisplay = true
        saveDrawings()
    }

    func undo() {
        // If paths is empty and we have a backup, restore the cleared paths
        if paths.isEmpty, let backup = clearedPathsBackup {
            paths = backup
            clearedPathsBackup = nil
            needsDisplay = true
            saveDrawings()
            return
        }

        guard !paths.isEmpty else { return }
        paths.removeLast()
        needsDisplay = true
        saveDrawings()
    }

    // MARK: - Persistence

    private func saveDrawings() {
        let pathData = paths.compactMap { path -> [String: Any]? in
            var dict: [String: Any] = [:]
            dict["points"] = path.points.map { ["x": $0.x, "y": $0.y] }
            dict["color"] = path.color.hexString
            dict["lineWidth"] = path.lineWidth
            dict["shape"] = path.shape.rawValue
            if let text = path.text {
                dict["text"] = text
            }
            if let fontSize = path.fontSize {
                dict["fontSize"] = fontSize
            }
            return dict
        }

        if let data = try? JSONSerialization.data(withJSONObject: pathData) {
            UserDefaults.standard.set(data, forKey: "com.telescope.drawings")
        }
    }

    private func loadDrawings() {
        guard let data = UserDefaults.standard.data(forKey: "com.telescope.drawings"),
              let pathData = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        paths = pathData.compactMap { dict -> DrawingPath? in
            guard let pointsData = dict["points"] as? [[String: CGFloat]],
                  let colorHex = dict["color"] as? String,
                  let lineWidth = dict["lineWidth"] as? CGFloat,
                  let shapeRaw = dict["shape"] as? String,
                  let shape = DrawingShape(rawValue: shapeRaw) else {
                return nil
            }

            let points = pointsData.compactMap { pointDict -> NSPoint? in
                guard let x = pointDict["x"], let y = pointDict["y"] else { return nil }
                return NSPoint(x: x, y: y)
            }

            let color = NSColor(hexString: colorHex) ?? .black
            let text = dict["text"] as? String
            let fontSize = dict["fontSize"] as? CGFloat

            return DrawingPath(
                points: points,
                color: color,
                lineWidth: lineWidth,
                shape: shape,
                text: text,
                fontSize: fontSize
            )
        }

        needsDisplay = true
    }
}

class DrawingPath {
    var points: [NSPoint]
    let color: NSColor
    let lineWidth: CGFloat
    let shape: DrawingShape
    let text: String?
    let fontSize: CGFloat?

    init(points: [NSPoint], color: NSColor, lineWidth: CGFloat, shape: DrawingShape, text: String? = nil, fontSize: CGFloat? = nil) {
        self.points = points
        self.color = color
        self.lineWidth = lineWidth
        self.shape = shape
        self.text = text
        self.fontSize = fontSize
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
    func didChangeFontSize(_ size: CGFloat)
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

    func didChangeFontSize(_ size: CGFloat) {
        fontSize = size
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
    private var contentView: NSView?
    private var visualEffectView: NSVisualEffectView?
    private var foldButton: NSButton?
    private var isFolded = false


    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupToolbar() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Use visual effect view for proper macOS aesthetic
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1
        visualEffect.layer?.borderColor = NSColor.black.withAlphaComponent(0.2).cgColor
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)
        self.visualEffectView = visualEffect

        // Container for all controls
        let contentView = NSView(frame: NSRect(x: 14, y: 0, width: frame.width - 28, height: frame.height))
        visualEffect.addSubview(contentView)
        self.contentView = contentView

        let yCenter: CGFloat = frame.height / 2
        var xOffset: CGFloat = 0

        // Colors section
        for color in DrawingColor.allCases {
            let button = createColorButton(color: color, x: xOffset, y: yCenter - 12)
            colorButtons.append(button)
            contentView.addSubview(button)
            xOffset += 26

            if color == .red {
                selectedColorButton = button
                button.layer?.borderWidth = 2
                button.layer?.borderColor = NSColor.white.cgColor
            }
        }

        // Separator
        xOffset += 6
        contentView.addSubview(createSeparator(x: xOffset, y: yCenter - 12))
        xOffset += 10

        // Shapes section
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

        for (shape, icon) in shapes {
            let button = createShapeButton(shape: shape, icon: icon, x: xOffset, y: yCenter - 12)
            shapeButtons.append(button)
            contentView.addSubview(button)
            xOffset += 28

            if shape == .select {
                selectedShapeButton = button
                button.layer?.borderWidth = 1.5
                button.layer?.borderColor = NSColor.controlAccentColor.cgColor
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            }
        }

        // Eraser mode button (hidden by default)
        let eraserModeButton = createActionButton(icon: "arrow.triangle.2.circlepath", x: xOffset, y: yCenter - 12, action: #selector(eraserModeToggleTapped))
        eraserModeButton.alphaValue = 0
        eraserModeButton.tag = 999
        contentView.addSubview(eraserModeButton)

        // Separator
        xOffset += 6
        contentView.addSubview(createSeparator(x: xOffset, y: yCenter - 12))
        xOffset += 10

        // Line thickness slider
        let lineIcon = NSImageView(frame: NSRect(x: xOffset, y: yCenter - 6, width: 12, height: 12))
        lineIcon.image = NSImage(systemSymbolName: "lineweight", accessibilityDescription: nil)
        lineIcon.contentTintColor = .secondaryLabelColor
        contentView.addSubview(lineIcon)
        xOffset += 14

        let slider = NSSlider(frame: NSRect(x: xOffset, y: yCenter - 8, width: 45, height: 16))
        slider.minValue = 1
        slider.maxValue = 10
        slider.doubleValue = 3
        slider.target = self
        slider.action = #selector(thicknessChanged(_:))
        slider.controlSize = .mini
        contentView.addSubview(slider)
        xOffset += 50

        // Font size slider
        let textIcon = NSImageView(frame: NSRect(x: xOffset, y: yCenter - 6, width: 12, height: 12))
        textIcon.image = NSImage(systemSymbolName: "textformat.size", accessibilityDescription: nil)
        textIcon.contentTintColor = .secondaryLabelColor
        contentView.addSubview(textIcon)
        xOffset += 14

        let fontSizeSlider = NSSlider(frame: NSRect(x: xOffset, y: yCenter - 8, width: 45, height: 16))
        fontSizeSlider.minValue = 12
        fontSizeSlider.maxValue = 48
        fontSizeSlider.doubleValue = 18
        fontSizeSlider.target = self
        fontSizeSlider.action = #selector(fontSizeChanged(_:))
        fontSizeSlider.controlSize = .mini
        contentView.addSubview(fontSizeSlider)
        xOffset += 50

        // Separator
        contentView.addSubview(createSeparator(x: xOffset, y: yCenter - 12))
        xOffset += 10

        // Undo button
        let undoButton = createActionButton(icon: "arrow.uturn.backward", x: xOffset, y: yCenter - 12, action: #selector(undoTapped))
        contentView.addSubview(undoButton)
        xOffset += 28

        // Clear button
        let clearButton = createActionButton(icon: "trash", x: xOffset, y: yCenter - 12, action: #selector(clearTapped))
        contentView.addSubview(clearButton)
        xOffset += 30

        // ESC badge
        let escBadge = NSView(frame: NSRect(x: xOffset, y: yCenter - 8, width: 28, height: 16))
        escBadge.wantsLayer = true
        escBadge.layer?.cornerRadius = 3
        escBadge.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.12).cgColor
        contentView.addSubview(escBadge)

        let escLabel = NSTextField(labelWithString: "esc")
        escLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        escLabel.textColor = .tertiaryLabelColor
        escLabel.frame = NSRect(x: 0, y: 0, width: 28, height: 14)
        escLabel.alignment = .center
        escLabel.isBordered = false
        escLabel.isEditable = false
        escLabel.backgroundColor = .clear
        escBadge.addSubview(escLabel)

        // Fold button (chevron down to hide toolbar)
        let foldBtn = NSButton(frame: NSRect(x: frame.width - 32, y: (frame.height - 20) / 2, width: 20, height: 20))
        foldBtn.title = ""
        foldBtn.wantsLayer = true
        foldBtn.isBordered = false
        foldBtn.layer?.cornerRadius = 4

        if let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            foldBtn.image = image.withSymbolConfiguration(config)
            foldBtn.contentTintColor = .tertiaryLabelColor
        }

        foldBtn.target = self
        foldBtn.action = #selector(foldToggleTapped)
        visualEffect.addSubview(foldBtn)
        self.foldButton = foldBtn
    }

    @objc private func foldToggleTapped() {
        isFolded.toggle()

        let expandedWidth: CGFloat = 760
        let expandedHeight: CGFloat = 52
        let collapsedSize: CGFloat = 40  // Perfect circle

        // Calculate center X position for parent
        guard let superview = superview else { return }
        let superWidth = superview.bounds.width

        let targetWidth: CGFloat = isFolded ? collapsedSize : expandedWidth
        let targetHeight: CGFloat = isFolded ? collapsedSize : expandedHeight
        let targetX = (superWidth - targetWidth) / 2
        let targetCornerRadius: CGFloat = isFolded ? collapsedSize / 2 : 12

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            // Animate frame change
            self.animator().frame = NSRect(x: targetX, y: self.frame.origin.y, width: targetWidth, height: targetHeight)

            // Hide/show content
            self.contentView?.animator().alphaValue = isFolded ? 0 : 1

            // Update corner radius for circle effect
            self.visualEffectView?.layer?.cornerRadius = targetCornerRadius

            // Update fold button icon and position
            if let foldBtn = self.foldButton {
                let iconName = isFolded ? "chevron.up" : "chevron.down"
                if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                    let config = NSImage.SymbolConfiguration(pointSize: isFolded ? 12 : 10, weight: .semibold)
                    foldBtn.image = image.withSymbolConfiguration(config)
                }
                // Center fold button when collapsed, right-align when expanded
                if isFolded {
                    foldBtn.frame = NSRect(x: (collapsedSize - 20) / 2, y: (collapsedSize - 20) / 2, width: 20, height: 20)
                } else {
                    foldBtn.frame = NSRect(x: targetWidth - 32, y: (expandedHeight - 20) / 2, width: 20, height: 20)
                }
            }
        })
    }

    private func createSeparator(x: CGFloat, y: CGFloat) -> NSView {
        let separator = NSView(frame: NSRect(x: x, y: y, width: 1, height: 24))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        return separator
    }

    @objc private func thicknessChanged(_ sender: NSSlider) {
        delegate?.didChangeThickness(CGFloat(sender.doubleValue))
    }

    @objc private func fontSizeChanged(_ sender: NSSlider) {
        delegate?.didChangeFontSize(CGFloat(sender.doubleValue))
    }

    private func createColorButton(color: DrawingColor, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 24, height: 24))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.layer?.backgroundColor = color.nsColor.cgColor
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1.5
        button.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor

        button.target = self
        button.action = #selector(colorButtonTapped(_:))
        button.tag = DrawingColor.allCases.firstIndex(of: color) ?? 0
        return button
    }

    private func createShapeButton(shape: DrawingShape, icon: String, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: y, width: 24, height: 24))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        button.layer?.cornerRadius = 5
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor

        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
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
        let button = NSButton(frame: NSRect(x: x, y: y, width: 24, height: 24))
        button.title = ""
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        button.layer?.cornerRadius = 5
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor

        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
            button.contentTintColor = .secondaryLabelColor
        }

        button.target = self
        button.action = action
        return button
    }

    @objc private func colorButtonTapped(_ sender: NSButton) {
        // Deselect previous
        selectedColorButton?.layer?.borderWidth = 1.5
        selectedColorButton?.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor

        // Select new
        sender.layer?.borderWidth = 2.5
        sender.layer?.borderColor = NSColor.white.cgColor
        selectedColorButton = sender

        let color = DrawingColor.allCases[sender.tag]
        delegate?.didSelectColor(color)
    }

    @objc private func shapeButtonTapped(_ sender: NSButton) {
        // Deselect previous
        selectedShapeButton?.layer?.borderWidth = 1
        selectedShapeButton?.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        selectedShapeButton?.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor

        // Select new
        sender.layer?.borderWidth = 2
        sender.layer?.borderColor = NSColor.controlAccentColor.cgColor
        sender.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        selectedShapeButton = sender

        let shapes: [DrawingShape] = [.select, .freehand, .line, .rectangle, .circle, .arrow, .text, .eraser]
        let shape = shapes[sender.tag]

        // Show/hide eraser mode toggle button and label
        if shape == .eraser {
            // Show eraser mode controls with animation
            if let eraserModeButton = contentView?.subviews.first(where: { $0.tag == 999 }) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    eraserModeButton.animator().alphaValue = 1
                    eraserModeLabel?.animator().alphaValue = 1
                })
            }
        } else {
            // Hide eraser mode controls with animation
            if let eraserModeButton = contentView?.subviews.first(where: { $0.tag == 999 }) {
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

    func selectShapeButton(for shape: DrawingShape) {
        let shapes: [DrawingShape] = [.select, .freehand, .line, .rectangle, .circle, .arrow, .text, .eraser]
        guard let index = shapes.firstIndex(of: shape), index < shapeButtons.count else { return }

        // Deselect previous
        selectedShapeButton?.layer?.borderWidth = 1
        selectedShapeButton?.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        selectedShapeButton?.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor

        // Select new
        let button = shapeButtons[index]
        button.layer?.borderWidth = 2
        button.layer?.borderColor = NSColor.controlAccentColor.cgColor
        button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        selectedShapeButton = button
    }
}

// MARK: - NSColor Extensions for Persistence
extension NSColor {
    var hexString: String {
        guard let rgbColor = usingColorSpace(.deviceRGB) else { return "#000000" }
        let r = Int(rgbColor.redComponent * 255.0)
        let g = Int(rgbColor.greenComponent * 255.0)
        let b = Int(rgbColor.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hex.count == 6 {
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            return nil
        }
    }
}