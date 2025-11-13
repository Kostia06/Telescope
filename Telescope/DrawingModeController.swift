import Cocoa

// Custom window that accepts key events even when borderless
class DrawingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class DrawingModeController {
    private var overlayWindow: DrawingWindow?
    private var drawingView: DrawingView?
    private var isActive = false
    
    func toggleDrawingMode() {
        if isActive {
            exitDrawingMode()
        } else {
            enterDrawingMode()
        }
    }
    
    private func enterDrawingMode() {
        guard let screen = NSScreen.main else { return }

        let window = DrawingWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let drawingView = DrawingView(frame: window.contentView!.bounds)
        drawingView.controller = self
        window.contentView = drawingView

        self.drawingView = drawingView
        self.overlayWindow = window
        self.isActive = true

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Ensure the drawing view becomes first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(drawingView)
        }
    }
    
    private func exitDrawingMode() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        drawingView = nil
        isActive = false
    }
    
    func setColor(_ color: DrawingColor) {
        drawingView?.currentColor = color
    }
    
    func setShape(_ shape: DrawingShape) {
        drawingView?.currentShape = shape
    }
    
    func clear() {
        drawingView?.clear()
    }
    
    func undo() {
        drawingView?.undo()
    }
}