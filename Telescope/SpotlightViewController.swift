import Cocoa

// MARK: - NSBezierPath CGPath Extension
extension NSBezierPath {
    var compatibleCGPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}

// MARK: - Draggable View for File Drops
class DraggableNotchView: NSView {
    weak var fileTrayView: FileTrayView?
    var onFilesDropped: (([URL]) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            onDragEntered?()
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return false
        }

        onFilesDropped?(urls)
        return true
    }
}

class SpotlightViewController: NSViewController {
    private var commandManager: CommandManager
    private weak var windowController: SpotlightWindowController?

    private var searchField: NSTextField!
    private var resultsTableView: NSTableView!
    private var scrollView: NSScrollView!
    private var visualEffectView: NSVisualEffectView!
    private var filteredCommands: [Command] = []
    private var searchIconView: NSImageView!
    private var sha256View: SHA256View!
    private var calcView: CalcView!
    private var musicView: MusicView!
    private var fileTrayView: FileTrayView!
    private var timerView: TimerView!
    private var defineView: DefineView!
    private var colorView: ColorView!
    private var emojiView: EmojiView!
    private var systemInfoView: SystemInfoView!
    private var convertView: ConvertView!

    // Debounce timer for search
    private var searchDebounceTimer: Timer?

    // Mask layer for notch shape
    private var notchMaskLayer: CAShapeLayer?

    // Track if file tray is showing
    private var isFileTrayVisible = false

    init(commandManager: CommandManager, windowController: SpotlightWindowController) {
        self.commandManager = commandManager
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
        commandManager.setSpotlightViewController(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Drop indicator for file drag
    private var dropIndicatorView: NSView?

    override func loadView() {
        let draggableView = DraggableNotchView(frame: NSRect(x: 0, y: 0, width: 480, height: 56))
        draggableView.onFilesDropped = { [weak self] urls in
            self?.handleFilesDropped(urls)
        }
        draggableView.onDragEntered = { [weak self] in
            self?.showDropIndicator()
        }
        draggableView.onDragExited = { [weak self] in
            self?.hideDropIndicator()
        }
        view = draggableView
        setupUI()
        filteredCommands = []
    }

    private func showDropIndicator() {
        if dropIndicatorView == nil {
            dropIndicatorView = NSView(frame: view.bounds)
            dropIndicatorView?.wantsLayer = true
            dropIndicatorView?.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            dropIndicatorView?.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            dropIndicatorView?.layer?.borderWidth = 2
            dropIndicatorView?.layer?.cornerRadius = 20
            dropIndicatorView?.alphaValue = 0
            dropIndicatorView?.autoresizingMask = [.width, .height]
            view.addSubview(dropIndicatorView!, positioned: .above, relativeTo: nil)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            dropIndicatorView?.animator().alphaValue = 1
        }
    }

    private func hideDropIndicator() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            dropIndicatorView?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.dropIndicatorView?.removeFromSuperview()
            self?.dropIndicatorView = nil
        })
    }

    private func handleFilesDropped(_ urls: [URL]) {
        // Add files to the tray and show it
        fileTrayView.addFiles(urls)
        showFileTrayInterface()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateNotchMask()
    }

    private func updateNotchMask() {
        let bounds = view.bounds
        let radius: CGFloat = 20

        // Round all corners
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        if notchMaskLayer == nil {
            notchMaskLayer = CAShapeLayer()
            view.layer?.mask = notchMaskLayer
        }

        notchMaskLayer?.path = path.compatibleCGPath
    }

    private func setupUI() {
        // Main view setup
        view.wantsLayer = true
        view.layer?.masksToBounds = true

        // Dark translucent background - Apple style
        let darkBackground = NSView(frame: view.bounds)
        darkBackground.wantsLayer = true
        darkBackground.layer?.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.95).cgColor
        darkBackground.autoresizingMask = [.width, .height]
        view.addSubview(darkBackground)

        // Round all corners
        updateNotchMask()

        // Visual effect container with blur - Apple style
        visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.alphaValue = 1.0
        visualEffectView.autoresizingMask = [.width, .height]
        view.addSubview(visualEffectView)

        // Search container
        let searchContainer = NSView(frame: NSRect(x: 0, y: view.bounds.height - 56, width: view.bounds.width, height: 56))
        searchContainer.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(searchContainer)

        // Search icon - Apple style tertiary label color
        searchIconView = NSImageView(frame: NSRect(x: 18, y: 16, width: 24, height: 24))
        searchIconView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIconView.contentTintColor = NSColor.tertiaryLabelColor
        searchIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        searchContainer.addSubview(searchIconView)

        // Search field - Apple style
        searchField = NSTextField(frame: NSRect(x: 50, y: 14, width: view.bounds.width - 68, height: 28))
        searchField.placeholderString = "Search"
        searchField.font = NSFont.systemFont(ofSize: 20, weight: .regular)
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.delegate = self
        searchField.textColor = NSColor.labelColor
        searchField.isEditable = true
        searchField.isSelectable = true

        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 20, weight: .regular)
        ]
        searchField.placeholderAttributedString = NSAttributedString(string: "Search", attributes: placeholderAttrs)
        searchContainer.addSubview(searchField)

        // Results table view
        resultsTableView = NSTableView(frame: .zero)
        resultsTableView.headerView = nil
        resultsTableView.backgroundColor = .clear
        resultsTableView.focusRingType = .none
        resultsTableView.intercellSpacing = NSSize(width: 0, height: 0)
        resultsTableView.rowHeight = 48
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.target = self
        resultsTableView.doubleAction = #selector(executeSelectedCommand)
        resultsTableView.selectionHighlightStyle = .regular
        resultsTableView.gridStyleMask = []

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
        column.width = view.bounds.width - 32
        resultsTableView.addTableColumn(column)

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 0))
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .light
        scrollView.autoresizingMask = [.width, .height]
        scrollView.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        visualEffectView.addSubview(scrollView)

        // SHA-256 view (hidden initially)
        sha256View = SHA256View(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        sha256View.autoresizingMask = [.width]
        sha256View.isHidden = true
        sha256View.onClose = { [weak self] in
            self?.windowController?.hidePanel()
        }
        sha256View.onEscape = { [weak self] in
            self?.closeSHA256Interface()
        }
        visualEffectView.addSubview(sha256View)

        // Calculator view (hidden initially)
        calcView = CalcView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        calcView.autoresizingMask = [.width]
        calcView.isHidden = true
        calcView.onClose = { [weak self] in
            self?.windowController?.hidePanel()
        }
        calcView.onEscape = { [weak self] in
            self?.closeCalcInterface()
        }
        visualEffectView.addSubview(calcView)

        // Music view (hidden initially)
        musicView = MusicView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        musicView.autoresizingMask = [.width]
        musicView.isHidden = true
        musicView.stopUpdating()
        musicView.onClose = { [weak self] in
            self?.windowController?.hidePanel()
        }
        musicView.onEscape = { [weak self] in
            self?.closeMusicInterface()
        }
        visualEffectView.addSubview(musicView)

        // File tray view (hidden initially)
        fileTrayView = FileTrayView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 140))
        fileTrayView.autoresizingMask = [.width]
        fileTrayView.isHidden = true
        fileTrayView.onClose = { [weak self] in
            self?.windowController?.hidePanel()
        }
        fileTrayView.onEscape = { [weak self] in
            self?.closeFileTrayInterface()
        }
        fileTrayView.onFilesChanged = { [weak self] in
            // Update window if all files removed
            if self?.fileTrayView.hasFiles == false {
                self?.closeFileTrayInterface()
            }
        }
        visualEffectView.addSubview(fileTrayView)

        // Timer view (hidden initially)
        timerView = TimerView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        timerView.autoresizingMask = [.width]
        timerView.isHidden = true
        timerView.onEscape = { [weak self] in
            self?.closeTimerInterface()
        }
        visualEffectView.addSubview(timerView)

        // Define view (hidden initially)
        defineView = DefineView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 140))
        defineView.autoresizingMask = [.width]
        defineView.isHidden = true
        defineView.onEscape = { [weak self] in
            self?.closeDefineInterface()
        }
        visualEffectView.addSubview(defineView)

        // Color view (hidden initially)
        colorView = ColorView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        colorView.autoresizingMask = [.width]
        colorView.isHidden = true
        colorView.onEscape = { [weak self] in
            self?.closeColorInterface()
        }
        visualEffectView.addSubview(colorView)

        // Emoji view (hidden initially)
        emojiView = EmojiView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 140))
        emojiView.autoresizingMask = [.width]
        emojiView.isHidden = true
        emojiView.onEscape = { [weak self] in
            self?.closeEmojiInterface()
        }
        visualEffectView.addSubview(emojiView)

        // System info view (hidden initially)
        systemInfoView = SystemInfoView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        systemInfoView.autoresizingMask = [.width]
        systemInfoView.isHidden = true
        systemInfoView.onEscape = { [weak self] in
            self?.closeSystemInfoInterface()
        }
        visualEffectView.addSubview(systemInfoView)

        // Convert view (hidden initially)
        convertView = ConvertView(frame: NSRect(x: 0, y: 0, width: view.bounds.width, height: 108))
        convertView.autoresizingMask = [.width]
        convertView.isHidden = true
        convertView.onEscape = { [weak self] in
            self?.closeConvertInterface()
        }
        visualEffectView.addSubview(convertView)
    }

    func focusSearchField() {
        searchField.stringValue = ""
        filteredCommands = []
        resultsTableView.reloadData()
        resultsTableView.deselectAll(nil)

        // Hide all special interfaces except file tray if it has files
        sha256View.isHidden = true
        calcView.isHidden = true
        musicView.isHidden = true
        musicView.stopUpdating()
        timerView.isHidden = true
        defineView.isHidden = true
        colorView.isHidden = true
        emojiView.isHidden = true
        systemInfoView.isHidden = true
        systemInfoView.stopUpdating()
        convertView.isHidden = true

        // Show file tray if it has files, otherwise show scroll view
        if fileTrayView.hasFiles {
            fileTrayView.isHidden = false
            scrollView.isHidden = true
            isFileTrayVisible = true
            windowController?.updateWindowHeightManual(height: 196) // 56 + 140
        } else {
            fileTrayView.isHidden = true
            scrollView.isHidden = false
            isFileTrayVisible = false
            windowController?.updateWindowHeight(for: 0)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.view.window?.makeFirstResponder(self.searchField)
            self.searchField.becomeFirstResponder()
        }
    }

    @objc func executeSelectedCommand() {
        guard !filteredCommands.isEmpty else { return }

        let selectedRow = resultsTableView.selectedRow
        let rowToExecute = (selectedRow >= 0 && selectedRow < filteredCommands.count) ? selectedRow : 0
        let command = filteredCommands[rowToExecute]

        if case .clipboardItem(let item) = command.type {
            showClipboardOptionsMenu(for: item, at: rowToExecute)
            return
        }

        // Special handling for SHA-256 command
        if command.name == ":sha-256" {
            searchField.stringValue = ":sha-256"
            showSHA256Interface()
            return
        }

        // Special handling for calculator command
        if command.name == ":calc" {
            searchField.stringValue = ":calc"
            showCalcInterface()
            return
        }

        // Special handling for music command
        if command.name == ":music" {
            searchField.stringValue = ":music"
            showMusicInterface()
            return
        }

        command.action()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.windowController?.hidePanel()
        }
    }

    private func showClipboardOptionsMenu(for item: ClipboardItem, at row: Int) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(clipboardPaste(_:)), keyEquivalent: "")
        pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        pasteItem.representedObject = item
        pasteItem.target = self
        menu.addItem(pasteItem)

        let copyItem = NSMenuItem(title: "Copy to Clipboard", action: #selector(clipboardCopy(_:)), keyEquivalent: "")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.representedObject = item
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        let previewItem = NSMenuItem(title: "Preview", action: #selector(clipboardPreview(_:)), keyEquivalent: "")
        previewItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        previewItem.representedObject = item
        previewItem.target = self
        menu.addItem(previewItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(title: "Remove", action: #selector(clipboardDelete(_:)), keyEquivalent: "")
        deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        deleteItem.representedObject = item
        deleteItem.target = self
        menu.addItem(deleteItem)

        let rowRect = resultsTableView.rect(ofRow: row)
        let pointInTable = NSPoint(x: rowRect.midX, y: rowRect.minY)
        let pointInWindow = resultsTableView.convert(pointInTable, to: nil)
        menu.popUp(positioning: nil, at: pointInWindow, in: view)
    }

    @objc private func clipboardPaste(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        ClipboardManager.shared.paste(item: item)
        windowController?.hidePanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    @objc private func clipboardCopy(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        ClipboardManager.shared.paste(item: item)
        windowController?.hidePanel()
    }

    @objc private func clipboardPreview(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }

        let alert = NSAlert()
        alert.messageText = "Clipboard Content"
        alert.informativeText = item.content
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Close")

        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardManager.shared.paste(item: item)
        }
    }

    @objc private func clipboardDelete(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        ClipboardManager.shared.removeItem(item)

        filteredCommands = commandManager.filterCommands(with: searchField.stringValue)
        resultsTableView.reloadData()
        windowController?.updateWindowHeight(for: filteredCommands.count)

        if !filteredCommands.isEmpty {
            resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
}

// MARK: - NSTextFieldDelegate
extension SpotlightViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let searchText = textField.stringValue

        searchDebounceTimer?.invalidate()

        // Update search icon color based on input - Apple style
        searchIconView.contentTintColor = searchText.isEmpty ? NSColor.tertiaryLabelColor : NSColor.secondaryLabelColor

        // Check for special commands - show inline interfaces
        let searchLower = searchText.lowercased()

        // Calculator command
        if searchLower == ":calc" || searchLower == ":calculator" {
            showCalcInterface()
            return
        }

        // Music command
        if searchLower == ":music" || searchLower == ":now" {
            showMusicInterface()
            return
        }

        // SHA-256 command
        if searchLower == ":sha-256" || searchLower == ":sha256" || searchLower == ":hash" {
            showSHA256Interface()
            return
        }

        // Timer command
        if searchLower == ":timer" || searchLower == ":stopwatch" {
            showTimerInterface()
            return
        }

        // Define/Dictionary command
        if searchLower == ":define" || searchLower == ":dict" || searchLower == ":dictionary" {
            showDefineInterface()
            return
        }

        // Color command
        if searchLower == ":color" || searchLower == ":colour" || searchLower == ":hex" {
            showColorInterface()
            return
        }

        // Emoji command
        if searchLower == ":emoji" || searchLower == ":emojis" {
            showEmojiInterface()
            return
        }

        // System info command
        if searchLower == ":sys" || searchLower == ":system" || searchLower == ":info" {
            showSystemInfoInterface()
            return
        }

        // Convert command
        if searchLower == ":convert" || searchLower == ":unit" || searchLower == ":units" {
            showConvertInterface()
            return
        }

        // File tray command
        if searchLower == ":tray" || searchLower == ":files" {
            showFileTrayInterface()
            return
        }

        // Hide all special interfaces for other searches
        hideAllSpecialInterfaces()

        if searchText.hasPrefix(":") {
            filteredCommands = commandManager.filterCommands(with: searchText)
            if searchText.lowercased() == ":edit" {
                if let editCommand = commandManager.commands.first(where: { $0.name == ":edit" }) {
                    filteredCommands.append(editCommand)
                }
            }
            resultsTableView.reloadData()
            windowController?.updateWindowHeight(for: filteredCommands.count)
            if !filteredCommands.isEmpty {
                resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(0)
            }
        } else if !searchText.isEmpty {
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                self.commandManager.searchFiles(query: searchText) { [weak self] results in
                    guard let self = self else { return }
                    guard textField.stringValue == searchText else { return }

                    self.filteredCommands = results
                    self.resultsTableView.reloadData()
                    self.windowController?.updateWindowHeight(for: results.count)
                    if !results.isEmpty {
                        self.resultsTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                        self.resultsTableView.scrollRowToVisible(0)
                    }
                }
            }
        } else {
            filteredCommands = []
            resultsTableView.reloadData()
            windowController?.updateWindowHeight(for: 0)
        }
    }

    private func showSHA256Interface() {
        // Prepare SHA256 view for animation
        sha256View.alphaValue = 0
        sha256View.isHidden = false

        // Animate out scroll view, animate in SHA256 view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            scrollView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.scrollView.isHidden = true
            self?.scrollView.alphaValue = 1
        })

        // Update window height
        let newHeight: CGFloat = 164 // 56 (search bar) + 108 (sha256 view)
        windowController?.updateWindowHeightManual(height: newHeight)

        // Animate in SHA256 view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.sha256View.animator().alphaValue = 1
            })
            self?.sha256View.reset()
            self?.sha256View.focusTextField()
        }
    }

    private func hideSHA256Interface() {
        if !sha256View.isHidden {
            sha256View.isHidden = true
            scrollView.isHidden = false
        }
    }

    private func closeSHA256Interface() {
        // Clear search field and hide SHA-256 interface
        searchField.stringValue = ""
        sha256View.isHidden = true
        scrollView.isHidden = false

        // Reset to minimal height
        windowController?.updateWindowHeight(for: 0)

        // Focus back on search field
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    private func showCalcInterface() {
        // Prepare calc view for animation
        sha256View.isHidden = true
        calcView.alphaValue = 0
        calcView.isHidden = false

        // Animate out scroll view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            scrollView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.scrollView.isHidden = true
            self?.scrollView.alphaValue = 1
        })

        // Update window height
        let newHeight: CGFloat = 164 // 56 (search bar) + 108 (calc view)
        windowController?.updateWindowHeightManual(height: newHeight)

        // Animate in calc view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.calcView.animator().alphaValue = 1
            })
            self?.calcView.reset()
            self?.calcView.focusTextField()
        }
    }

    private func hideCalcInterface() {
        if !calcView.isHidden {
            calcView.isHidden = true
            scrollView.isHidden = false
        }
    }

    private func closeCalcInterface() {
        // Clear search field and hide calculator interface
        searchField.stringValue = ""
        calcView.isHidden = true
        scrollView.isHidden = false

        // Reset to minimal height
        windowController?.updateWindowHeight(for: 0)

        // Focus back on search field
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    private func showMusicInterface() {
        // Prepare music view for animation
        sha256View.isHidden = true
        calcView.isHidden = true
        musicView.alphaValue = 0
        musicView.isHidden = false

        // Animate out scroll view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            scrollView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.scrollView.isHidden = true
            self?.scrollView.alphaValue = 1
        })

        // Update window height
        let newHeight: CGFloat = 164 // 56 (search bar) + 108 (music view)
        windowController?.updateWindowHeightManual(height: newHeight)

        // Animate in music view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.musicView.animator().alphaValue = 1
            })
            self?.musicView.reset()
            self?.musicView.startUpdating()
        }
    }

    private func hideMusicInterface() {
        if !musicView.isHidden {
            musicView.isHidden = true
            musicView.stopUpdating()
            scrollView.isHidden = false
        }
    }

    private func closeMusicInterface() {
        // Clear search field and hide music interface
        searchField.stringValue = ""
        musicView.isHidden = true
        musicView.stopUpdating()
        scrollView.isHidden = false

        // Reset to minimal height
        windowController?.updateWindowHeight(for: 0)

        // Focus back on search field
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    private func hideAllSpecialInterfaces() {
        hideSHA256Interface()
        hideCalcInterface()
        hideMusicInterface()
        hideFileTrayInterface()
        hideTimerInterface()
        hideDefineInterface()
        hideColorInterface()
        hideEmojiInterface()
        hideSystemInfoInterface()
        hideConvertInterface()
    }

    private func hideFileTrayInterface() {
        if !fileTrayView.isHidden && !fileTrayView.hasFiles {
            fileTrayView.isHidden = true
            scrollView.isHidden = false
            isFileTrayVisible = false
        }
    }

    private func closeFileTrayInterface() {
        fileTrayView.clearFiles()
        fileTrayView.isHidden = true
        scrollView.isHidden = false
        isFileTrayVisible = false
        windowController?.updateWindowHeight(for: 0)

        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    private func showFileTrayInterface() {
        // Prepare file tray view for animation
        sha256View.isHidden = true
        calcView.isHidden = true
        musicView.isHidden = true
        musicView.stopUpdating()
        fileTrayView.alphaValue = 0
        fileTrayView.isHidden = false
        isFileTrayVisible = true

        // Animate out scroll view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            scrollView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.scrollView.isHidden = true
            self?.scrollView.alphaValue = 1
        })

        // Update window height
        windowController?.updateWindowHeightManual(height: 196) // 56 + 140

        // Animate in file tray view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.fileTrayView.animator().alphaValue = 1
            })
        }
    }

    // MARK: - Timer Interface
    private func showTimerInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        timerView.alphaValue = 0
        timerView.isHidden = false

        windowController?.updateWindowHeightManual(height: 164)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.timerView.animator().alphaValue = 1
            })
            self?.timerView.focusTextField()
        }
    }

    private func hideTimerInterface() {
        if !timerView.isHidden {
            timerView.isHidden = true
        }
    }

    private func closeTimerInterface() {
        timerView.isHidden = true
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    // MARK: - Define Interface
    private func showDefineInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        defineView.alphaValue = 0
        defineView.isHidden = false

        windowController?.updateWindowHeightManual(height: 196)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.defineView.animator().alphaValue = 1
            })
            self?.defineView.reset()
            self?.defineView.focusTextField()
        }
    }

    private func hideDefineInterface() {
        if !defineView.isHidden {
            defineView.isHidden = true
        }
    }

    private func closeDefineInterface() {
        defineView.isHidden = true
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    // MARK: - Color Interface
    private func showColorInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        colorView.alphaValue = 0
        colorView.isHidden = false

        windowController?.updateWindowHeightManual(height: 164)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.colorView.animator().alphaValue = 1
            })
            self?.colorView.reset()
            self?.colorView.focusTextField()
        }
    }

    private func hideColorInterface() {
        if !colorView.isHidden {
            colorView.isHidden = true
        }
    }

    private func closeColorInterface() {
        colorView.isHidden = true
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    // MARK: - Emoji Interface
    private func showEmojiInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        emojiView.alphaValue = 0
        emojiView.isHidden = false

        windowController?.updateWindowHeightManual(height: 196)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.emojiView.animator().alphaValue = 1
            })
            self?.emojiView.reset()
            self?.emojiView.focusTextField()
        }
    }

    private func hideEmojiInterface() {
        if !emojiView.isHidden {
            emojiView.isHidden = true
        }
    }

    private func closeEmojiInterface() {
        emojiView.isHidden = true
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    // MARK: - System Info Interface
    private func showSystemInfoInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        systemInfoView.alphaValue = 0
        systemInfoView.isHidden = false

        windowController?.updateWindowHeightManual(height: 164)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.systemInfoView.animator().alphaValue = 1
            })
            self?.systemInfoView.reset()
        }
    }

    private func hideSystemInfoInterface() {
        if !systemInfoView.isHidden {
            systemInfoView.isHidden = true
            systemInfoView.stopUpdating()
        }
    }

    private func closeSystemInfoInterface() {
        systemInfoView.isHidden = true
        systemInfoView.stopUpdating()
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    // MARK: - Convert Interface
    private func showConvertInterface() {
        hideAllSpecialInterfaces()
        scrollView.isHidden = true
        convertView.alphaValue = 0
        convertView.isHidden = false

        windowController?.updateWindowHeightManual(height: 164)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
                self?.convertView.animator().alphaValue = 1
            })
            self?.convertView.reset()
            self?.convertView.focusTextField()
        }
    }

    private func hideConvertInterface() {
        if !convertView.isHidden {
            convertView.isHidden = true
        }
    }

    private func closeConvertInterface() {
        convertView.isHidden = true
        scrollView.isHidden = false
        windowController?.updateWindowHeight(for: 0)
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.searchField)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            // Check for Command key modifier for force quit
            if NSEvent.modifierFlags.contains(.command) {
                executeForceQuitIfApp()
            } else {
                executeSelectedCommand()
            }
            return true
        case #selector(NSResponder.moveDown(_:)):
            let selected = resultsTableView.selectedRow
            if selected < filteredCommands.count - 1 {
                resultsTableView.selectRowIndexes(IndexSet(integer: selected + 1), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(selected + 1)
            }
            return true
        case #selector(NSResponder.moveUp(_:)):
            let selected = resultsTableView.selectedRow
            if selected > 0 {
                resultsTableView.selectRowIndexes(IndexSet(integer: selected - 1), byExtendingSelection: false)
                resultsTableView.scrollRowToVisible(selected - 1)
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            windowController?.hidePanel()
            return true
        default:
            return false
        }
    }

    private func executeForceQuitIfApp() {
        guard !filteredCommands.isEmpty else { return }

        let selectedRow = resultsTableView.selectedRow
        let rowToExecute = (selectedRow >= 0 && selectedRow < filteredCommands.count) ? selectedRow : 0
        let command = filteredCommands[rowToExecute]

        // Only force quit for app type
        if case .app(let path) = command.type {
            // Check if app is running
            if Command.isAppRunning(path: path, name: command.name) {
                Command.forceQuitApp(path: path, name: command.name)

                // Show brief feedback then close
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.windowController?.hidePanel()
                }
            } else {
                // App not running, just execute normally
                executeSelectedCommand()
            }
        } else {
            // Not an app, execute normally
            executeSelectedCommand()
        }
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension SpotlightViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredCommands.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = CommandCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 48))
        cellView.configure(with: filteredCommands[row])
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CommandRowView()
    }
}
