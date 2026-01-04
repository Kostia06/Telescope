import Cocoa
import CryptoKit

class SHA256View: NSView, NSTextFieldDelegate {
    private var textField: NSTextField!
    private var secureTextField: NSSecureTextField!
    private var roundsField: NSTextField!
    private var roundsStepper: NSStepper!
    private var calculateButton: NSButton!
    private var toggleVisibilityButton: NSButton!
    private var resultLabel: NSTextField!
    private var copyButton: NSButton!
    private var isTextVisible = true
    private var currentHash: String = ""

    // Private pasteboard for SHA256 results (not main clipboard)
    private let sha256Pasteboard = NSPasteboard(name: NSPasteboard.Name("com.telescope.sha256"))

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.drawsAsynchronously = true

        // Main container with padding
        let containerPadding: CGFloat = 12

        // Regular text input field - Apple style (top row)
        textField = NSTextField(frame: NSRect(x: containerPadding, y: 68, width: 310, height: 28))
        textField.placeholderString = "Enter text to hash"
        textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textField.focusRingType = .none
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.textColor = NSColor.labelColor
        textField.delegate = self
        addSubview(textField)

        // Secure text field - hidden initially
        secureTextField = NSSecureTextField(frame: NSRect(x: containerPadding, y: 68, width: 310, height: 28))
        secureTextField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        secureTextField.focusRingType = .none
        secureTextField.isBordered = false
        secureTextField.isBezeled = false
        secureTextField.drawsBackground = false
        secureTextField.textColor = NSColor.labelColor
        secureTextField.delegate = self
        secureTextField.isHidden = true
        addSubview(secureTextField)

        // Visibility toggle button - Apple style
        toggleVisibilityButton = NSButton(frame: NSRect(x: 329, y: 72, width: 20, height: 20))
        toggleVisibilityButton.title = ""
        toggleVisibilityButton.bezelStyle = .texturedRounded
        toggleVisibilityButton.isBordered = false
        toggleVisibilityButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Toggle visibility")
        toggleVisibilityButton.imagePosition = .imageOnly
        toggleVisibilityButton.contentTintColor = NSColor.secondaryLabelColor
        toggleVisibilityButton.target = self
        toggleVisibilityButton.action = #selector(toggleTextVisibility)
        addSubview(toggleVisibilityButton)

        // Rounds field - Apple style
        roundsField = NSTextField(frame: NSRect(x: 360, y: 70, width: 32, height: 20))
        roundsField.integerValue = 1
        roundsField.alignment = .center
        roundsField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        roundsField.focusRingType = .none
        roundsField.isBordered = false
        roundsField.isBezeled = false
        roundsField.drawsBackground = false
        roundsField.textColor = NSColor.labelColor
        addSubview(roundsField)

        // Rounds stepper
        roundsStepper = NSStepper(frame: NSRect(x: 396, y: 72, width: 19, height: 16))
        roundsStepper.minValue = 1
        roundsStepper.maxValue = 100000
        roundsStepper.integerValue = 1
        roundsStepper.target = roundsField
        roundsStepper.action = #selector(NSTextField.takeIntValueFrom(_:))
        addSubview(roundsStepper)

        // Calculate button
        calculateButton = NSButton(frame: NSRect(x: 424, y: 72, width: 24, height: 20))
        calculateButton.title = ""
        calculateButton.bezelStyle = .texturedRounded
        calculateButton.isBordered = false
        calculateButton.image = NSImage(systemSymbolName: "arrow.right.circle.fill", accessibilityDescription: "Calculate")
        calculateButton.imagePosition = .imageOnly
        calculateButton.contentTintColor = .controlAccentColor
        calculateButton.target = self
        calculateButton.action = #selector(calculateHash)
        calculateButton.keyEquivalent = "\r"
        addSubview(calculateButton)

        // Separator line
        let separator = NSBox(frame: NSRect(x: containerPadding, y: 54, width: bounds.width - (containerPadding * 2), height: 1))
        separator.boxType = .separator
        separator.alphaValue = 0.15
        addSubview(separator)

        // Result label (bottom row) - shows the hash - Apple style
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.frame = NSRect(x: containerPadding, y: 16, width: bounds.width - containerPadding - 50, height: 28)
        resultLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        resultLabel.textColor = NSColor.secondaryLabelColor
        resultLabel.lineBreakMode = .byTruncatingMiddle
        resultLabel.isSelectable = true
        resultLabel.isEditable = false
        resultLabel.isBordered = false
        resultLabel.drawsBackground = false
        addSubview(resultLabel)

        // Copy button (only shown when result is available) - Apple style
        copyButton = NSButton(frame: NSRect(x: bounds.width - 40, y: 20, width: 28, height: 20))
        copyButton.title = ""
        copyButton.bezelStyle = .texturedRounded
        copyButton.isBordered = false
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy to clipboard")
        copyButton.imagePosition = .imageOnly
        copyButton.contentTintColor = NSColor.controlAccentColor
        copyButton.target = self
        copyButton.action = #selector(copyToClipboard)
        copyButton.isHidden = true
        addSubview(copyButton)
    }

    @objc private func calculateHash() {
        let text = isTextVisible ? textField.stringValue : secureTextField.stringValue
        guard !text.isEmpty else { return }

        let rounds = max(1, roundsField.integerValue)
        currentHash = text

        for _ in 0..<rounds {
            if let data = currentHash.data(using: .utf8) {
                let hash = SHA256.hash(data: data)
                currentHash = hash.compactMap { String(format: "%02x", $0) }.joined()
            }
        }

        // Display the hash result (do NOT copy to main clipboard)
        resultLabel.stringValue = currentHash
        copyButton.isHidden = false

        // Store in private pasteboard (not main clipboard)
        sha256Pasteboard.clearContents()
        sha256Pasteboard.setString(currentHash, forType: .string)

        // Animate result appearance
        resultLabel.alphaValue = 0
        copyButton.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1, 0.5, 1)
            resultLabel.animator().alphaValue = 1
            copyButton.animator().alphaValue = 1
        })
    }

    @objc private func copyToClipboard() {
        guard !currentHash.isEmpty else { return }

        // Copy to main clipboard when user explicitly requests
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentHash, forType: .string)

        // Visual feedback - change icon to checkmark briefly
        copyButton.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")
        copyButton.contentTintColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy to clipboard")
            self?.copyButton.contentTintColor = NSColor.controlAccentColor
        }
    }

    @objc private func toggleTextVisibility() {
        isTextVisible = !isTextVisible

        if isTextVisible {
            // Show regular text field
            textField.isHidden = false
            secureTextField.isHidden = true
            secureTextField.stringValue = textField.stringValue
            toggleVisibilityButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Toggle visibility")
            window?.makeFirstResponder(textField)
        } else {
            // Show secure text field
            textField.isHidden = true
            secureTextField.isHidden = false
            secureTextField.stringValue = textField.stringValue
            toggleVisibilityButton.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "Toggle visibility")
            window?.makeFirstResponder(secureTextField)
        }
    }

    func focusTextField() {
        window?.makeFirstResponder(textField)
    }

    func reset() {
        textField.stringValue = ""
        secureTextField.stringValue = ""
        roundsField.integerValue = 1
        roundsStepper.integerValue = 1
        isTextVisible = true
        textField.isHidden = false
        secureTextField.isHidden = true
        toggleVisibilityButton.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Toggle visibility")

        // Clear previous result
        resultLabel.stringValue = ""
        currentHash = ""
        copyButton.isHidden = true
    }

    // MARK: - NSTextFieldDelegate
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // ESC key pressed
            onEscape?()
            return true
        }
        return false
    }
}
