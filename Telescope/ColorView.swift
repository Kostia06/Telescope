import Cocoa

class ColorView: NSView, NSTextFieldDelegate {
    private var inputField: NSTextField!
    private var colorPreview: NSView!
    private var hexLabel: NSTextField!
    private var rgbLabel: NSTextField!
    private var hslLabel: NSTextField!
    private var copyHexButton: NSButton!
    private var copyRgbButton: NSButton!
    private var pickerButton: NSButton!

    private var currentColor: NSColor = .controlAccentColor

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

        let padding: CGFloat = 16

        // Color preview box
        colorPreview = NSView(frame: NSRect(x: padding, y: 24, width: 60, height: 60))
        colorPreview.wantsLayer = true
        colorPreview.layer?.cornerRadius = 12
        colorPreview.layer?.backgroundColor = currentColor.cgColor
        colorPreview.layer?.borderWidth = 1
        colorPreview.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(colorPreview)

        // Input field for hex/rgb
        inputField = NSTextField(frame: NSRect(x: 88, y: 62, width: 180, height: 24))
        inputField.placeholderString = "#FF5733 or rgb(255,87,51)"
        inputField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = NSColor.labelColor
        inputField.delegate = self
        addSubview(inputField)

        // Hex label
        hexLabel = NSTextField(labelWithString: "")
        hexLabel.frame = NSRect(x: 88, y: 42, width: 100, height: 16)
        hexLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        hexLabel.textColor = NSColor.secondaryLabelColor
        addSubview(hexLabel)

        // RGB label
        rgbLabel = NSTextField(labelWithString: "")
        rgbLabel.frame = NSRect(x: 88, y: 24, width: 150, height: 16)
        rgbLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        rgbLabel.textColor = NSColor.tertiaryLabelColor
        addSubview(rgbLabel)

        // HSL label
        hslLabel = NSTextField(labelWithString: "")
        hslLabel.frame = NSRect(x: 240, y: 24, width: 150, height: 16)
        hslLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        hslLabel.textColor = NSColor.tertiaryLabelColor
        addSubview(hslLabel)

        // Copy Hex button
        copyHexButton = NSButton(frame: NSRect(x: 280, y: 58, width: 60, height: 24))
        copyHexButton.title = "Copy"
        copyHexButton.bezelStyle = .recessed
        copyHexButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        copyHexButton.target = self
        copyHexButton.action = #selector(copyHex)
        addSubview(copyHexButton)

        // Screen picker button
        pickerButton = NSButton(frame: NSRect(x: 348, y: 58, width: 90, height: 24))
        pickerButton.title = "Pick Color"
        pickerButton.bezelStyle = .recessed
        pickerButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        pickerButton.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: nil)
        pickerButton.imagePosition = .imageLeading
        pickerButton.target = self
        pickerButton.action = #selector(pickColorFromScreen)
        addSubview(pickerButton)

        // Set initial color
        updateColorDisplay()
    }

    func controlTextDidChange(_ obj: Notification) {
        let input = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        if let color = parseColor(input) {
            currentColor = color
            updateColorDisplay()
        }
    }

    private func parseColor(_ input: String) -> NSColor? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()

        // Try hex format
        if let color = parseHex(trimmed) {
            return color
        }

        // Try rgb format
        if let color = parseRGB(trimmed) {
            return color
        }

        // Try named colors
        if let color = parseNamedColor(trimmed) {
            return color
        }

        return nil
    }

    private func parseHex(_ input: String) -> NSColor? {
        var hex = input
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }

        // Handle 3-character hex
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        guard hex.count == 6, let hexInt = UInt64(hex, radix: 16) else {
            return nil
        }

        let r = CGFloat((hexInt >> 16) & 0xFF) / 255.0
        let g = CGFloat((hexInt >> 8) & 0xFF) / 255.0
        let b = CGFloat(hexInt & 0xFF) / 255.0

        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }

    private func parseRGB(_ input: String) -> NSColor? {
        // Match rgb(r, g, b) or r, g, b
        let pattern = #"(?:rgba?\s*\()?\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }

        guard let rRange = Range(match.range(at: 1), in: input),
              let gRange = Range(match.range(at: 2), in: input),
              let bRange = Range(match.range(at: 3), in: input),
              let r = Int(input[rRange]),
              let g = Int(input[gRange]),
              let b = Int(input[bRange]) else {
            return nil
        }

        return NSColor(calibratedRed: CGFloat(r) / 255.0,
                       green: CGFloat(g) / 255.0,
                       blue: CGFloat(b) / 255.0,
                       alpha: 1.0)
    }

    private func parseNamedColor(_ name: String) -> NSColor? {
        let colors: [String: NSColor] = [
            "red": .systemRed,
            "orange": .systemOrange,
            "yellow": .systemYellow,
            "green": .systemGreen,
            "blue": .systemBlue,
            "purple": .systemPurple,
            "pink": .systemPink,
            "brown": .systemBrown,
            "gray": .systemGray,
            "grey": .systemGray,
            "black": .black,
            "white": .white,
            "cyan": .cyan,
            "magenta": .magenta
        ]
        return colors[name]
    }

    private func updateColorDisplay() {
        // Update preview
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            colorPreview.animator().layer?.backgroundColor = currentColor.cgColor
        }

        // Get RGB components
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let rgbColor = currentColor.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }

        let rInt = Int(r * 255)
        let gInt = Int(g * 255)
        let bInt = Int(b * 255)

        // Update hex label
        let hex = String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        hexLabel.stringValue = hex

        // Update RGB label
        rgbLabel.stringValue = "rgb(\(rInt), \(gInt), \(bInt))"

        // Calculate and update HSL
        let (h, s, l) = rgbToHSL(r: r, g: g, b: b)
        hslLabel.stringValue = String(format: "hsl(%.0f, %.0f%%, %.0f%%)", h, s * 100, l * 100)
    }

    private func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2

        if maxC == minC {
            return (0, 0, l)
        }

        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)

        var h: CGFloat = 0
        if maxC == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h *= 60

        return (h, s, l)
    }

    @objc private func copyHex() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let rgbColor = currentColor.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }

        let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)

        // Feedback
        copyHexButton.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyHexButton.title = "Copy"
        }
    }

    @objc private func pickColorFromScreen() {
        // Use NSColorSampler for screen color picking (macOS 10.15+)
        let sampler = NSColorSampler()
        sampler.show { [weak self] selectedColor in
            if let color = selectedColor {
                self?.currentColor = color
                self?.updateColorDisplay()

                // Update input field with hex
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if let rgbColor = color.usingColorSpace(.deviceRGB) {
                    rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                }
                let hex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                self?.inputField.stringValue = hex
            }
        }
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        inputField.stringValue = ""
        currentColor = .controlAccentColor
        updateColorDisplay()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscape?()
            return true
        }
        return false
    }
}
