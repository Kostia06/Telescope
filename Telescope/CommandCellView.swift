import Cocoa

class CommandCellView: NSView {
    private var iconView: NSImageView!
    private var nameLabel: NSTextField!
    private var descLabel: NSTextField!
    private var iconContainer: NSView!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Icon container - Apple style with subtle background
        let iconSize: CGFloat = 32
        let iconY = (bounds.height - iconSize) / 2
        iconContainer = NSView(frame: NSRect(x: 12, y: iconY, width: iconSize, height: iconSize))
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        addSubview(iconContainer)

        // Icon
        iconView = NSImageView(frame: NSRect(x: 6, y: 6, width: 20, height: 20))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addSubview(iconView)

        // Name label - Apple style primary label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.frame = NSRect(x: 52, y: bounds.height / 2 + 2, width: bounds.width - 64, height: 16)
        nameLabel.textColor = NSColor.labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.cell?.truncatesLastVisibleLine = true
        addSubview(nameLabel)

        // Description label - Apple style secondary label
        descLabel = NSTextField(labelWithString: "")
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.frame = NSRect(x: 52, y: bounds.height / 2 - 14, width: bounds.width - 64, height: 14)
        descLabel.lineBreakMode = .byTruncatingTail
        descLabel.cell?.truncatesLastVisibleLine = true
        addSubview(descLabel)
    }

    func configure(with command: Command) {
        nameLabel.stringValue = command.name
        descLabel.stringValue = command.description

        if let customIcon = command.customIcon {
            iconView.image = customIcon
            iconView.contentTintColor = nil
            iconContainer.layer?.backgroundColor = NSColor.clear.cgColor
            iconView.frame = NSRect(x: 2, y: 2, width: 28, height: 28)
        } else {
            iconView.image = NSImage(systemSymbolName: command.icon, accessibilityDescription: nil)
            iconView.contentTintColor = NSColor.controlAccentColor
            iconContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            iconView.frame = NSRect(x: 6, y: 6, width: 20, height: 20)
        }
    }
}
