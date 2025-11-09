import Cocoa

class CommandCellView: NSView {
    private var iconView: NSImageView!
    private var nameLabel: NSTextField!
    private var descLabel: NSTextField!
    private var containerView: NSView!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        containerView = NSView(frame: bounds.insetBy(dx: 6, dy: 3))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        addSubview(containerView)

        // Icon with enhanced background - centered vertically
        let iconSize: CGFloat = 32
        let iconY = (bounds.height - iconSize) / 2 - 3
        let iconContainer = NSView(frame: NSRect(x: 8, y: iconY, width: iconSize, height: iconSize))
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        containerView.addSubview(iconContainer)

        iconView = NSImageView(frame: NSRect(x: 2, y: 2, width: 28, height: 28))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addSubview(iconView)

        // Name label - positioned properly
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameLabel.frame = NSRect(x: 48, y: 23, width: 440, height: 17)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.cell?.truncatesLastVisibleLine = true
        containerView.addSubview(nameLabel)

        // Description label - positioned below name
        descLabel = NSTextField(labelWithString: "")
        descLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 48, y: 7, width: 440, height: 14)
        descLabel.lineBreakMode = .byTruncatingMiddle
        descLabel.cell?.truncatesLastVisibleLine = true
        containerView.addSubview(descLabel)
    }
    
    func configure(with command: Command) {
        nameLabel.stringValue = command.name
        descLabel.stringValue = command.description
        iconView.image = NSImage(systemSymbolName: command.icon, accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor
    }
}
