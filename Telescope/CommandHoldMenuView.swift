import Cocoa

class CommandHoldMenuView: NSView {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSTextField!
    private var allOptions: [CommandOption] = []
    private var filteredOptions: [CommandOption] = []
    private var selectedIndex: Int = 0
    private var titleText: String

    var onOptionSelected: ((CommandOption) -> Void)?

    init(frame: NSRect, options: [CommandOption], title: String = "Available Commands") {
        self.titleText = title
        super.init(frame: frame)
        self.allOptions = options
        self.filteredOptions = options
        setupUI()
        setupKeyMonitoring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true

        // Background visual effect view
        let visualEffect = NSVisualEffectView(frame: bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.autoresizingMask = [.width, .height]
        addSubview(visualEffect)

        // Title label
        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: bounds.height - 40, width: bounds.width - 40, height: 24)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        addSubview(titleLabel)

        // Search field container with icon
        let searchContainer = NSView(frame: NSRect(x: 20, y: bounds.height - 102, width: bounds.width - 40, height: 36))
        searchContainer.wantsLayer = true
        searchContainer.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.1).cgColor
        searchContainer.layer?.cornerRadius = 8
        searchContainer.layer?.borderWidth = 1
        searchContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        searchContainer.autoresizingMask = [.width, .minYMargin]
        addSubview(searchContainer)

        // Search icon
        let searchIcon = NSTextField(labelWithString: "🔍")
        searchIcon.font = .systemFont(ofSize: 16)
        searchIcon.frame = NSRect(x: 12, y: 8, width: 20, height: 20)
        searchContainer.addSubview(searchIcon)

        // Search field
        searchField = NSTextField(frame: NSRect(x: 38, y: 6, width: searchContainer.bounds.width - 46, height: 24))
        searchField.placeholderString = "Type to search commands..."
        searchField.font = .systemFont(ofSize: 13)
        searchField.isBordered = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.autoresizingMask = [.width]
        searchContainer.addSubview(searchField)

        // Subtitle label with keyboard shortcuts
        let subtitleLabel = NSTextField(labelWithString: "↑↓ Navigate  •  ⏎ Execute  •  ⎋ Close")
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .medium)
        subtitleLabel.textColor = .tertiaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: bounds.height - 122, width: bounds.width - 40, height: 12)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        addSubview(subtitleLabel)

        // Separator
        let separator = NSBox(frame: NSRect(x: 16, y: bounds.height - 130, width: bounds.width - 32, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        addSubview(separator)

        // Table view setup
        scrollView = NSScrollView(frame: NSRect(x: 16, y: 16, width: bounds.width - 32, height: bounds.height - 148))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        tableView = NSTableView(frame: scrollView.bounds)
        tableView.autoresizingMask = [.width, .height]
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.rowHeight = 50
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.gridStyleMask = []

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
        column.width = scrollView.bounds.width
        tableView.addTableColumn(column)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        addSubview(scrollView)

        // Select first row
        if !filteredOptions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        // Focus search field
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.searchField)
        }
    }

    private func setupKeyMonitoring() {
        // Monitor for arrow keys and Enter
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let window = self.window, window.isKeyWindow else {
            return event
        }

        switch event.keyCode {
        case 125: // Down arrow
            moveSelectionDown()
            return nil
        case 126: // Up arrow
            moveSelectionUp()
            return nil
        case 36: // Enter/Return
            executeSelectedOption()
            return nil
        case 53: // Escape
            window.close()
            return nil
        default:
            return event
        }
    }

    private func moveSelectionDown() {
        selectedIndex = min(selectedIndex + 1, filteredOptions.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    private func moveSelectionUp() {
        selectedIndex = max(selectedIndex - 1, 0)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    private func executeSelectedOption() {
        guard selectedIndex < filteredOptions.count else { return }
        let option = filteredOptions[selectedIndex]
        onOptionSelected?(option)
    }

    private func filterOptions(_ searchText: String) {
        if searchText.isEmpty {
            filteredOptions = allOptions
        } else {
            let lowercasedSearch = searchText.lowercased()
            filteredOptions = allOptions.filter { option in
                option.title.lowercased().contains(lowercasedSearch) ||
                option.description.lowercased().contains(lowercasedSearch)
            }
        }

        selectedIndex = 0
        tableView.reloadData()
        if !filteredOptions.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
}

// MARK: - NSTableViewDataSource
extension CommandHoldMenuView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredOptions.count
    }
}

// MARK: - NSTableViewDelegate
extension CommandHoldMenuView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let option = filteredOptions[row]

        let cellView = CommandOptionCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 50))
        cellView.configure(with: option)

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedIndex = row
        return true
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = CommandOptionRowView()
        return rowView
    }
}

// MARK: - NSTextFieldDelegate
extension CommandHoldMenuView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        filterOptions(textField.stringValue)
    }
}

// MARK: - Cell View
class CommandOptionCellView: NSView {
    private var titleLabel: NSTextField!
    private var descriptionLabel: NSTextField!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 12, y: 22, width: bounds.width - 24, height: 18)
        titleLabel.autoresizingMask = [.width]
        addSubview(titleLabel)

        // Description
        descriptionLabel = NSTextField(labelWithString: "")
        descriptionLabel.font = .systemFont(ofSize: 11, weight: .regular)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.frame = NSRect(x: 12, y: 6, width: bounds.width - 24, height: 14)
        descriptionLabel.autoresizingMask = [.width]
        addSubview(descriptionLabel)
    }

    func configure(with option: CommandOption) {
        titleLabel.stringValue = option.title
        descriptionLabel.stringValue = option.description
    }
}

// MARK: - Row View
class CommandOptionRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 8, dy: 2)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3).setFill()
            path.fill()
        }
    }

    override var isEmphasized: Bool {
        get { return false }
        set {}
    }
}
