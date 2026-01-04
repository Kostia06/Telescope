import Cocoa
import UniformTypeIdentifiers

// MARK: - Draggable File Item View
class DraggableFileItemView: NSView, NSDraggingSource {
    private var iconView: NSImageView!
    private var nameLabel: NSTextField!
    private var hoverOverlay: NSView!
    private var removeButton: NSButton!
    private var isHovered = false

    var fileURL: URL
    var onRemove: ((URL) -> Void)?
    var onDoubleClick: ((URL) -> Void)?

    private let iconSize: CGFloat = 52

    init(frame: NSRect, url: URL) {
        self.fileURL = url
        super.init(frame: frame)
        setupUI()
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        // Hover overlay - Apple style
        hoverOverlay = NSView(frame: bounds)
        hoverOverlay.wantsLayer = true
        hoverOverlay.layer?.cornerRadius = 10
        hoverOverlay.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        hoverOverlay.alphaValue = 0
        hoverOverlay.autoresizingMask = [.width, .height]
        addSubview(hoverOverlay)

        // File icon with shadow
        let iconY = bounds.height - iconSize - 12
        iconView = NSImageView(frame: NSRect(x: (bounds.width - iconSize) / 2, y: iconY, width: iconSize, height: iconSize))
        iconView.image = NSWorkspace.shared.icon(forFile: fileURL.path)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.shadowColor = NSColor.black.cgColor
        iconView.layer?.shadowOpacity = 0.2
        iconView.layer?.shadowOffset = CGSize(width: 0, height: -1)
        iconView.layer?.shadowRadius = 3
        addSubview(iconView)

        // Filename label - Apple style
        nameLabel = NSTextField(labelWithString: fileURL.lastPathComponent)
        nameLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        nameLabel.textColor = NSColor.labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.frame = NSRect(x: 4, y: 8, width: bounds.width - 8, height: 16)
        nameLabel.maximumNumberOfLines = 1
        addSubview(nameLabel)

        // Remove button (hidden by default) - Apple style
        removeButton = NSButton(frame: NSRect(x: bounds.width - 20, y: bounds.height - 20, width: 18, height: 18))
        removeButton.bezelStyle = .circular
        removeButton.isBordered = false
        removeButton.wantsLayer = true
        removeButton.layer?.cornerRadius = 9
        removeButton.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        removeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove")
        removeButton.contentTintColor = NSColor.labelColor
        removeButton.imagePosition = .imageOnly
        removeButton.target = self
        removeButton.action = #selector(removeClicked)
        removeButton.alphaValue = 0
        addSubview(removeButton)

        // Double-click gesture
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClick)
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            hoverOverlay.animator().alphaValue = 1
            removeButton.animator().alphaValue = 1
        }

        // Scale up icon slightly
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            iconView.animator().frame = NSRect(
                x: (bounds.width - iconSize - 4) / 2,
                y: bounds.height - iconSize - 10,
                width: iconSize + 4,
                height: iconSize + 4
            )
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            hoverOverlay.animator().alphaValue = 0
            removeButton.animator().alphaValue = 0
        }

        // Scale back icon
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            iconView.animator().frame = NSRect(
                x: (bounds.width - iconSize) / 2,
                y: bounds.height - iconSize - 12,
                width: iconSize,
                height: iconSize
            )
        }
    }

    @objc private func removeClicked() {
        // Animate removal with scale and fade
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1)
            self.animator().alphaValue = 0
        })

        // Scale down animation using layer
        if let layer = self.layer {
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 0.8
            scaleAnim.duration = 0.25
            scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1)
            layer.add(scaleAnim, forKey: "shrink")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            self.onRemove?(self.fileURL)
        }
    }

    @objc private func handleDoubleClick() {
        onDoubleClick?(fileURL)
    }

    // MARK: - Drag Source

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)

        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)

        // Create drag image from the icon
        let dragImage = NSWorkspace.shared.icon(forFile: fileURL.path)
        dragImage.size = NSSize(width: 48, height: 48)

        draggingItem.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: dragImage)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? .copy : .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 0.5
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }
}

// MARK: - File Tray View
class FileTrayView: NSView {
    private var fileItems: [URL] = []
    private var fileItemViews: [DraggableFileItemView] = []
    private var scrollView: NSScrollView!
    private var containerView: NSView!
    private var emptyStateView: NSView!
    private var headerView: NSView!
    private var countBadge: NSTextField!
    private var clearButton: NSButton!

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?
    var onFilesChanged: (() -> Void)?

    private let itemWidth: CGFloat = 80
    private let itemHeight: CGFloat = 90
    private let itemSpacing: CGFloat = 8
    private let headerHeight: CGFloat = 32

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true

        // Header with count and clear button
        headerView = NSView(frame: NSRect(x: 0, y: bounds.height - headerHeight, width: bounds.width, height: headerHeight))
        headerView.autoresizingMask = [.width, .minYMargin]
        addSubview(headerView)

        // Tray icon - Apple style
        let trayIcon = NSImageView(frame: NSRect(x: 16, y: 6, width: 20, height: 20))
        trayIcon.image = NSImage(systemSymbolName: "tray.fill", accessibilityDescription: nil)
        trayIcon.contentTintColor = NSColor.secondaryLabelColor
        headerView.addSubview(trayIcon)

        // Count badge - Apple style
        countBadge = NSTextField(labelWithString: "0 files")
        countBadge.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        countBadge.textColor = NSColor.secondaryLabelColor
        countBadge.frame = NSRect(x: 42, y: 6, width: 100, height: 20)
        headerView.addSubview(countBadge)

        // Clear all button - Apple style
        clearButton = NSButton(frame: NSRect(x: bounds.width - 80, y: 4, width: 70, height: 24))
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .recessed
        clearButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        clearButton.contentTintColor = NSColor.controlAccentColor
        clearButton.target = self
        clearButton.action = #selector(clearAllClicked)
        clearButton.autoresizingMask = [.minXMargin]
        clearButton.isHidden = true
        headerView.addSubview(clearButton)

        // Empty state
        emptyStateView = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - headerHeight))
        emptyStateView.autoresizingMask = [.width, .height]
        addSubview(emptyStateView)

        let emptyIcon = NSImageView(frame: NSRect(x: (bounds.width - 40) / 2, y: (emptyStateView.bounds.height - 40) / 2 + 10, width: 40, height: 40))
        emptyIcon.image = NSImage(systemSymbolName: "arrow.down.doc", accessibilityDescription: nil)
        emptyIcon.contentTintColor = NSColor.tertiaryLabelColor
        emptyIcon.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        emptyStateView.addSubview(emptyIcon)

        let emptyLabel = NSTextField(labelWithString: "Drop files here")
        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = NSColor.tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.frame = NSRect(x: 0, y: (emptyStateView.bounds.height - 40) / 2 - 20, width: bounds.width, height: 20)
        emptyLabel.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        emptyStateView.addSubview(emptyLabel)

        // Scroll view for file icons
        scrollView = NSScrollView(frame: NSRect(x: 8, y: 4, width: bounds.width - 16, height: bounds.height - headerHeight - 8))
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.autoresizingMask = [.width, .height]

        containerView = NSView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height))
        scrollView.documentView = containerView

        addSubview(scrollView)
        scrollView.isHidden = true
    }

    // MARK: - Drag and Drop (receiving files)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            highlightForDrop(true)
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlightForDrop(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        highlightForDrop(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return false
        }

        for url in urls {
            if !fileItems.contains(url) {
                fileItems.append(url)
            }
        }

        updateFileDisplay(animated: true)
        highlightForDrop(false)
        return true
    }

    private func highlightForDrop(_ highlight: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            self.layer?.backgroundColor = highlight ?
                NSColor.white.withAlphaComponent(0.1).cgColor :
                NSColor.clear.cgColor
        }

        // Animate empty state icon
        if highlight && fileItems.isEmpty {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
                emptyStateView.subviews.first?.animator().alphaValue = 0.6
            }
        } else if !highlight && fileItems.isEmpty {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                emptyStateView.subviews.first?.animator().alphaValue = 0.3
            }
        }
    }

    // MARK: - File Display

    private func updateFileDisplay(animated: Bool = false) {
        // Remove old views
        for view in fileItemViews {
            if animated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    view.animator().alphaValue = 0
                }, completionHandler: {
                    view.removeFromSuperview()
                })
            } else {
                view.removeFromSuperview()
            }
        }
        fileItemViews.removeAll()

        // Update count badge
        let count = fileItems.count
        countBadge.stringValue = count == 1 ? "1 file" : "\(count) files"
        clearButton.isHidden = count == 0

        if fileItems.isEmpty {
            emptyStateView.isHidden = false
            scrollView.isHidden = true
            return
        }

        emptyStateView.isHidden = true
        scrollView.isHidden = false

        // Calculate container width
        let totalWidth = CGFloat(fileItems.count) * (itemWidth + itemSpacing) - itemSpacing + 8
        containerView.frame = NSRect(x: 0, y: 0, width: max(totalWidth, scrollView.bounds.width), height: scrollView.bounds.height)

        // Create file item views with staggered animation
        for (index, url) in fileItems.enumerated() {
            let xPos = CGFloat(index) * (itemWidth + itemSpacing) + 4
            let yPos = (containerView.bounds.height - itemHeight) / 2

            let itemView = DraggableFileItemView(
                frame: NSRect(x: xPos, y: yPos, width: itemWidth, height: itemHeight),
                url: url
            )

            itemView.onRemove = { [weak self] url in
                self?.removeFile(url)
            }

            itemView.onDoubleClick = { url in
                NSWorkspace.shared.open(url)
            }

            if animated {
                itemView.alphaValue = 0
                itemView.frame = NSRect(x: xPos, y: yPos - 10, width: itemWidth, height: itemHeight)
            }

            containerView.addSubview(itemView)
            fileItemViews.append(itemView)

            if animated {
                let delay = Double(index) * 0.04
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.35
                        context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1) // Spring bounce
                        itemView.animator().alphaValue = 1
                        itemView.animator().frame = NSRect(x: xPos, y: yPos, width: self.itemWidth, height: self.itemHeight)
                    }
                }
            }
        }
    }

    private func removeFile(_ url: URL) {
        fileItems.removeAll { $0 == url }
        updateFileDisplay(animated: true)
        onFilesChanged?()
    }

    @objc private func clearAllClicked() {
        // Animate all items out with staggered fade and scale
        for (index, view) in fileItemViews.enumerated() {
            let delay = Double(index) * 0.025
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1)
                    view.animator().alphaValue = 0
                })

                // Scale down animation
                if let layer = view.layer {
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 1.0
                    scaleAnim.toValue = 0.7
                    scaleAnim.duration = 0.25
                    scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.6, 1)
                    layer.add(scaleAnim, forKey: "shrink")
                }
            }
        }

        // Clear after animation
        let totalDelay = Double(fileItemViews.count) * 0.025 + 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) { [weak self] in
            self?.fileItems.removeAll()
            self?.updateFileDisplay(animated: false)
            self?.onFilesChanged?()
        }
    }

    // MARK: - Keyboard handling

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Public methods

    func reset() {
        // Keep files in tray - don't clear
    }

    func clearFiles() {
        fileItems.removeAll()
        updateFileDisplay(animated: false)
    }

    func addFile(_ url: URL) {
        if !fileItems.contains(url) {
            fileItems.append(url)
            updateFileDisplay(animated: true)
        }
    }

    func addFiles(_ urls: [URL]) {
        var added = false
        for url in urls {
            if !fileItems.contains(url) {
                fileItems.append(url)
                added = true
            }
        }
        if added {
            updateFileDisplay(animated: true)
        }
    }

    var hasFiles: Bool {
        return !fileItems.isEmpty
    }

    var fileCount: Int {
        return fileItems.count
    }
}
