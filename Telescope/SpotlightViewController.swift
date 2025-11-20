import Cocoa

class SpotlightViewController: NSViewController {
    private var commandManager: CommandManager
    private weak var windowController: SpotlightWindowController?

    private var searchField: NSTextField!
    private var resultsTableView: NSTableView!
    private var scrollView: NSScrollView!
    private var visualEffectView: NSVisualEffectView!
    private var filteredCommands: [Command] = []

    // Debounce timer for search
    private var searchDebounceTimer: Timer?
    
    init(commandManager: CommandManager, windowController: SpotlightWindowController) {
        self.commandManager = commandManager
        self.windowController = windowController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 120))
        setupUI()
        filteredCommands = []
    }
    
    private func setupUI() {
        // Visual effect background with enhanced styling
        visualEffectView = NSVisualEffectView(frame: view.bounds)
        visualEffectView.material = .popover
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 14
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.autoresizingMask = [.width, .height]

        // Add subtle border
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor

        // Add shadow for depth
        view.wantsLayer = true
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.5
        view.layer?.shadowOffset = NSSize(width: 0, height: -4)
        view.layer?.shadowRadius = 20

        view.addSubview(visualEffectView)

        // Search field container (anchored to top)
        let searchContainerWidth: CGFloat = 560
        let searchContainerHeight: CGFloat = 60
        let searchContainer = NSView(frame: NSRect(x: (view.bounds.width - searchContainerWidth) / 2, y: view.bounds.height - searchContainerHeight - 8, width: searchContainerWidth, height: searchContainerHeight))
        searchContainer.autoresizingMask = [.minYMargin]
        visualEffectView.addSubview(searchContainer)

        // Search icon
        let searchIcon = NSImageView(frame: NSRect(x: 20, y: 20, width: 24, height: 24))
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = .secondaryLabelColor
        searchContainer.addSubview(searchIcon)

        // Search field with enhanced styling
        searchField = NSTextField(frame: NSRect(x: 52, y: 16, width: searchContainerWidth - 72, height: 32))
        searchField.placeholderString = "Search apps... (type : for commands)"
        searchField.font = NSFont.systemFont(ofSize: 22, weight: .light)
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.delegate = self
        searchField.textColor = .labelColor
        searchField.isEditable = true
        searchField.isSelectable = true

        // Add placeholder text attributes for better styling
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: NSFont.systemFont(ofSize: 22, weight: .light)
        ]
        searchField.placeholderAttributedString = NSAttributedString(string: "Search apps... (type : for commands)", attributes: attrs)

        searchContainer.addSubview(searchField)

        // Separator (anchored below search bar)
        let separatorY = view.bounds.height - searchContainerHeight - 10
        let separator = NSBox(frame: NSRect(x: 16, y: separatorY, width: 528, height: 1))
        separator.boxType = .separator
        separator.fillColor = NSColor.separatorColor.withAlphaComponent(0.3)
        separator.autoresizingMask = [.minYMargin]
        visualEffectView.addSubview(separator)

        // Results table view
        resultsTableView = NSTableView(frame: .zero)
        resultsTableView.headerView = nil
        resultsTableView.backgroundColor = .clear
        resultsTableView.focusRingType = .none
        resultsTableView.intercellSpacing = NSSize(width: 0, height: 2)
        resultsTableView.rowHeight = 50
        resultsTableView.delegate = self
        resultsTableView.dataSource = self
        resultsTableView.target = self
        resultsTableView.doubleAction = #selector(executeSelectedCommand)
        resultsTableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
        column.width = 512
        resultsTableView.addTableColumn(column)

        let scrollHeight = view.bounds.height - searchContainerHeight - 28
        scrollView = NSScrollView(frame: NSRect(x: 24, y: 0, width: 512, height: scrollHeight))
        scrollView.documentView = resultsTableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(scrollView)
    }
    
    func focusSearchField() {
        searchField.stringValue = ""
        filteredCommands = []
        resultsTableView.reloadData()
        resultsTableView.deselectAll(nil)
        windowController?.updateWindowHeight(for: 0)

        // Ensure the window and field can accept input
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.view.window?.makeFirstResponder(self.searchField)
            self.searchField.becomeFirstResponder()
        }
    }
    
    @objc func executeSelectedCommand() {
        guard !filteredCommands.isEmpty else {
            print("No commands to execute")
            return
        }

        let selectedRow = resultsTableView.selectedRow
        let rowToExecute = (selectedRow >= 0 && selectedRow < filteredCommands.count) ? selectedRow : 0
        let command = filteredCommands[rowToExecute]

        command.action()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.windowController?.hidePanel()
        }
    }
}

// MARK: - NSTextFieldDelegate
extension SpotlightViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let searchText = textField.stringValue

        // Cancel any pending search
        searchDebounceTimer?.invalidate()

        if searchText.hasPrefix(":") {
            // Command search - no debounce needed
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
            // File search - debounce to prevent excessive searches
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self else { return }

                self.commandManager.searchFiles(query: searchText) { [weak self] results in
                    guard let self = self else { return }
                    // Double-check the search text hasn't changed
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
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            executeSelectedCommand()
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
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension SpotlightViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredCommands.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellView = CommandCellView(frame: NSRect(x: 0, y: 0, width: 512, height: 50))
        let command = filteredCommands[row]
        cellView.configure(with: command)
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return CommandRowView()
    }
}
