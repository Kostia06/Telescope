import Cocoa

class NoteListCellView: NSView {
    private var titleLabel: NSTextField!
    private var previewLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var effectView: NSVisualEffectView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        // Visual effect view for glass background
        effectView = NSVisualEffectView(frame: bounds.insetBy(dx: 10, dy: 2))
        effectView.material = .hudWindow
        effectView.state = .inactive
        effectView.blendingMode = .withinWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        effectView.autoresizingMask = [.width, .height]
        addSubview(effectView)

        // Title label with better typography
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 18, y: 54, width: effectView.bounds.width - 36, height: 20)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.autoresizingMask = [.width]
        titleLabel.cell?.truncatesLastVisibleLine = true
        effectView.addSubview(titleLabel)

        // Preview label with better spacing
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        previewLabel.frame = NSRect(x: 18, y: 32, width: effectView.bounds.width - 36, height: 18)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.autoresizingMask = [.width]
        previewLabel.cell?.truncatesLastVisibleLine = true
        effectView.addSubview(previewLabel)

        // Date label
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        dateLabel.frame = NSRect(x: 18, y: 12, width: effectView.bounds.width - 36, height: 14)
        dateLabel.textColor = .tertiaryLabelColor
        dateLabel.lineBreakMode = .byTruncatingTail
        dateLabel.autoresizingMask = [.width]
        effectView.addSubview(dateLabel)
    }

    func configure(with note: Note, isSelected: Bool) {
        titleLabel.stringValue = note.title
        previewLabel.stringValue = note.preview
        dateLabel.stringValue = formatDate(note.lastModified)

        if isSelected {
            effectView.material = .selection
            effectView.state = .active
            effectView.layer?.borderWidth = 2
            effectView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            titleLabel.textColor = .labelColor
            previewLabel.textColor = .secondaryLabelColor
        } else {
            effectView.material = .hudWindow
            effectView.state = .active
            effectView.layer?.borderWidth = 1
            effectView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
            titleLabel.textColor = .labelColor
            previewLabel.textColor = .secondaryLabelColor
        }
    }

    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: now)

        if let seconds = components.second, seconds < 60 {
            return "just now"
        } else if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m ago"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h ago"
        } else if let days = components.day, days < 7 {
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

class NoteListRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Don't draw selection background - handled by cell
    }
}
