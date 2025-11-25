import Cocoa

class NotesViewController: NSViewController {
    private var splitView: NSSplitView!
    private var notesTableView: NSTableView!
    private var titleField: NSTextField!
    private var contentTextView: NSTextView!
    private var deleteButton: NSButton!
    private var newNoteButton: NSButton!

    private var notes: [Note] = []
    private var selectedNote: Note?
    private var isEditingNewNote = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
        setupUI()
        refreshNotes()
    }

    private func setupUI() {
        view.wantsLayer = true

        // Main visual effect view for glass background
        let mainEffectView = NSVisualEffectView(frame: view.bounds)
        mainEffectView.material = .underWindowBackground
        mainEffectView.blendingMode = .behindWindow
        mainEffectView.state = .active
        mainEffectView.autoresizingMask = [.width, .height]
        view.addSubview(mainEffectView)

        // Split view with custom divider
        splitView = NSSplitView(frame: view.bounds)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]
        mainEffectView.addSubview(splitView)

        // Left side - Notes list with glass effect
        let leftContainer = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 280, height: view.bounds.height))
        leftContainer.material = .underWindowBackground
        leftContainer.blendingMode = .withinWindow
        leftContainer.state = .active
        setupLeftSide(leftContainer)
        splitView.addArrangedSubview(leftContainer)

        // Right side - Note editor with glass effect
        let rightContainer = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 620, height: view.bounds.height))
        rightContainer.material = .underWindowBackground
        rightContainer.blendingMode = .withinWindow
        rightContainer.state = .active
        setupRightSide(rightContainer)
        splitView.addArrangedSubview(rightContainer)

        // Set split position
        splitView.setPosition(280, ofDividerAt: 0)
    }

    private func setupLeftSide(_ container: NSView) {
        container.wantsLayer = true

        // Toolbar area (accounting for titlebar)
        let toolbarHeight: CGFloat = 80
        let toolbar = NSView(frame: NSRect(x: 0, y: container.bounds.height - toolbarHeight, width: container.bounds.width, height: toolbarHeight))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        container.addSubview(toolbar)

        // Title (positioned lower to account for titlebar)
        let titleLabel = NSTextField(labelWithString: "Notes")
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.frame = NSRect(x: 20, y: 18, width: 150, height: 34)
        titleLabel.textColor = .labelColor
        toolbar.addSubview(titleLabel)

        // New note button with modern styling
        newNoteButton = NSButton(frame: NSRect(x: container.bounds.width - 58, y: 20, width: 38, height: 38))
        newNoteButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Note")
        newNoteButton.bezelStyle = .texturedRounded
        newNoteButton.isBordered = true
        newNoteButton.target = self
        newNoteButton.action = #selector(createNewNote)
        newNoteButton.autoresizingMask = [.minXMargin]
        newNoteButton.toolTip = "New Note"
        toolbar.addSubview(newNoteButton)

        // Clean separator line - full width
        let separator = NSBox(frame: NSRect(x: 0, y: toolbar.frame.minY, width: container.bounds.width, height: 1))
        separator.boxType = .separator
        separator.fillColor = NSColor.separatorColor
        separator.borderWidth = 0
        separator.autoresizingMask = [.width, .minYMargin]
        container.addSubview(separator)

        // Table view with vibrancy
        notesTableView = NSTableView(frame: .zero)
        notesTableView.headerView = nil
        notesTableView.backgroundColor = .clear
        notesTableView.focusRingType = .none
        notesTableView.intercellSpacing = NSSize(width: 0, height: 4)
        notesTableView.rowHeight = 88
        notesTableView.delegate = self
        notesTableView.dataSource = self
        notesTableView.target = self
        notesTableView.action = #selector(noteSelected)
        notesTableView.selectionHighlightStyle = .none
        notesTableView.style = .fullWidth

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NoteColumn"))
        column.width = 280
        notesTableView.addTableColumn(column)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height - toolbarHeight - 1))
        scrollView.documentView = notesTableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.autoresizingMask = [.width, .height]
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        container.addSubview(scrollView)
    }

    private func setupRightSide(_ container: NSView) {
        container.wantsLayer = true

        // Toolbar area (accounting for titlebar)
        let toolbarHeight: CGFloat = 80
        let toolbar = NSView(frame: NSRect(x: 0, y: container.bounds.height - toolbarHeight, width: container.bounds.width, height: toolbarHeight))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        container.addSubview(toolbar)

        // Delete button with modern styling
        deleteButton = NSButton(frame: NSRect(x: container.bounds.width - 58, y: 20, width: 38, height: 38))
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete Note")
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = true
        deleteButton.target = self
        deleteButton.action = #selector(deleteCurrentNote)
        deleteButton.autoresizingMask = [.minXMargin]
        deleteButton.isEnabled = false
        deleteButton.toolTip = "Delete Note"
        toolbar.addSubview(deleteButton)

        // Clean separator line - full width
        let separator = NSBox(frame: NSRect(x: 0, y: toolbar.frame.minY, width: container.bounds.width, height: 1))
        separator.boxType = .separator
        separator.fillColor = NSColor.separatorColor
        separator.borderWidth = 0
        separator.autoresizingMask = [.width, .minYMargin]
        container.addSubview(separator)

        // Content area
        let contentContainer = NSView(frame: NSRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height - toolbarHeight - 1))
        contentContainer.autoresizingMask = [.width, .height]
        container.addSubview(contentContainer)

        // Title field with better spacing
        titleField = NSTextField(frame: NSRect(x: 32, y: contentContainer.bounds.height - 64, width: contentContainer.bounds.width - 64, height: 44))
        titleField.placeholderString = "Note title"
        titleField.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleField.focusRingType = .none
        titleField.isBordered = false
        titleField.backgroundColor = .clear
        titleField.delegate = self
        titleField.autoresizingMask = [.width, .minYMargin]
        contentContainer.addSubview(titleField)

        // Separator between title and content
        let titleSeparator = NSBox(frame: NSRect(x: 32, y: contentContainer.bounds.height - 72, width: contentContainer.bounds.width - 64, height: 1))
        titleSeparator.boxType = .separator
        titleSeparator.fillColor = NSColor.separatorColor.withAlphaComponent(0.3)
        titleSeparator.borderWidth = 0
        titleSeparator.autoresizingMask = [.width, .minYMargin]
        contentContainer.addSubview(titleSeparator)

        // Content text view with scroll view and better spacing
        let contentScrollView = NSScrollView(frame: NSRect(x: 32, y: 24, width: contentContainer.bounds.width - 64, height: contentContainer.bounds.height - 108))
        contentScrollView.hasVerticalScroller = true
        contentScrollView.drawsBackground = false
        contentScrollView.borderType = .noBorder
        contentScrollView.scrollerStyle = .overlay
        contentScrollView.autoresizingMask = [.width, .height]

        contentTextView = NSTextView(frame: contentScrollView.bounds)
        contentTextView.isRichText = false
        contentTextView.font = NSFont.systemFont(ofSize: 16)
        contentTextView.textColor = .labelColor
        contentTextView.backgroundColor = .clear
        contentTextView.isEditable = true
        contentTextView.isSelectable = true
        contentTextView.delegate = self
        contentTextView.autoresizingMask = [.width, .height]
        contentTextView.textContainerInset = NSSize(width: 10, height: 10)

        contentScrollView.documentView = contentTextView
        contentContainer.addSubview(contentScrollView)

        // Empty state
        showEmptyState()
    }

    private func showEmptyState() {
        titleField.isEditable = false
        titleField.stringValue = ""
        contentTextView.isEditable = false
        contentTextView.string = notes.isEmpty ? "No notes yet. Click + to create your first note." : "Select a note to view or edit"
        contentTextView.textColor = .tertiaryLabelColor
        deleteButton.isEnabled = false
    }

    func refreshNotes() {
        notes = NotesManager.shared.getNotes()
        notesTableView.reloadData()

        if let selectedNote = selectedNote,
           let updatedNote = notes.first(where: { $0.id == selectedNote.id }) {
            self.selectedNote = updatedNote
            displayNote(updatedNote)
        } else if !notes.isEmpty && selectedNote == nil {
            selectFirstNote()
        } else if notes.isEmpty {
            selectedNote = nil
            showEmptyState()
        }
    }

    private func selectFirstNote() {
        if !notes.isEmpty {
            notesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            noteSelected()
        }
    }

    func selectNote(id: String) {
        if let index = notes.firstIndex(where: { $0.id == id }) {
            notesTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            noteSelected()
        }
    }

    @objc private func noteSelected() {
        let selectedRow = notesTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < notes.count else {
            showEmptyState()
            return
        }

        isEditingNewNote = false
        let note = notes[selectedRow]
        selectedNote = note
        displayNote(note)
        notesTableView.reloadData()
    }

    private func displayNote(_ note: Note) {
        titleField.isEditable = true
        titleField.stringValue = note.title
        contentTextView.isEditable = true
        contentTextView.textColor = .labelColor
        contentTextView.string = note.content
        deleteButton.isEnabled = true
    }

    @objc private func createNewNote() {
        let newNote = NotesManager.shared.createNote(title: "Untitled", content: "")
        isEditingNewNote = true
        refreshNotes()

        // Select the new note
        if let index = notes.firstIndex(where: { $0.id == newNote.id }) {
            notesTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            noteSelected()
            view.window?.makeFirstResponder(titleField)
        }
    }

    @objc private func deleteCurrentNote() {
        guard let note = selectedNote else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Note"
        alert.informativeText = "Are you sure you want to delete '\(note.title)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NotesManager.shared.deleteNote(id: note.id)
            selectedNote = nil
            refreshNotes()
        }
    }

    @objc private func saveCurrentNote() {
        guard let note = selectedNote else { return }

        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = contentTextView.string

        // If it's a new note and both fields are empty, delete it
        if isEditingNewNote && title.isEmpty && content.isEmpty {
            NotesManager.shared.deleteNote(id: note.id)
            isEditingNewNote = false
            refreshNotes()
            return
        }

        NotesManager.shared.updateNote(
            id: note.id,
            title: title.isEmpty ? "Untitled" : title,
            content: content
        )

        isEditingNewNote = false
        refreshNotes()
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
extension NotesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return notes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let note = notes[row]
        let isSelected = selectedNote?.id == note.id

        let cellView = NoteListCellView(frame: NSRect(x: 0, y: 0, width: 280, height: 80))
        cellView.configure(with: note, isSelected: isSelected)
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return NoteListRowView()
    }
}

// MARK: - NSTextFieldDelegate
extension NotesViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        saveCurrentNote()
    }
}

// MARK: - NSTextViewDelegate
extension NotesViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // Auto-save after typing stops
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(saveCurrentNote), object: nil)
        perform(#selector(saveCurrentNote), with: nil, afterDelay: 1.0)
    }
}
