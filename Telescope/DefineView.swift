import Cocoa

class DefineView: NSView, NSTextFieldDelegate {
    private var inputField: NSTextField!
    private var wordLabel: NSTextField!
    private var definitionLabel: NSTextField!
    private var scrollView: NSScrollView!
    private var partOfSpeechLabel: NSTextField!
    private var pronunciationLabel: NSTextField!

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

        // Input field for word
        inputField = NSTextField(frame: NSRect(x: padding, y: bounds.height - 36, width: bounds.width - padding * 2, height: 24))
        inputField.placeholderString = "Enter a word..."
        inputField.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = NSColor.labelColor
        inputField.delegate = self
        addSubview(inputField)

        // Word label (bold)
        wordLabel = NSTextField(labelWithString: "")
        wordLabel.frame = NSRect(x: padding, y: bounds.height - 64, width: bounds.width - padding * 2 - 100, height: 20)
        wordLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        wordLabel.textColor = NSColor.labelColor
        addSubview(wordLabel)

        // Part of speech
        partOfSpeechLabel = NSTextField(labelWithString: "")
        partOfSpeechLabel.frame = NSRect(x: padding, y: bounds.height - 82, width: 100, height: 16)
        let italicDescriptor = NSFont.systemFont(ofSize: 12).fontDescriptor.withSymbolicTraits(.italic)
        partOfSpeechLabel.font = NSFont(descriptor: italicDescriptor, size: 12)
        partOfSpeechLabel.textColor = NSColor.secondaryLabelColor
        addSubview(partOfSpeechLabel)

        // Pronunciation
        pronunciationLabel = NSTextField(labelWithString: "")
        pronunciationLabel.frame = NSRect(x: bounds.width - padding - 100, y: bounds.height - 64, width: 100, height: 20)
        pronunciationLabel.font = NSFont.systemFont(ofSize: 12)
        pronunciationLabel.textColor = NSColor.tertiaryLabelColor
        pronunciationLabel.alignment = .right
        addSubview(pronunciationLabel)

        // Separator
        let separator = NSBox(frame: NSRect(x: padding, y: bounds.height - 88, width: bounds.width - padding * 2, height: 1))
        separator.boxType = .separator
        separator.alphaValue = 0.2
        addSubview(separator)

        // Definition scroll view
        scrollView = NSScrollView(frame: NSRect(x: padding, y: 8, width: bounds.width - padding * 2, height: bounds.height - 100))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        definitionLabel = NSTextField(labelWithString: "")
        definitionLabel.font = NSFont.systemFont(ofSize: 13)
        definitionLabel.textColor = NSColor.secondaryLabelColor
        definitionLabel.isEditable = false
        definitionLabel.isBordered = false
        definitionLabel.drawsBackground = false
        definitionLabel.lineBreakMode = .byWordWrapping
        definitionLabel.preferredMaxLayoutWidth = scrollView.bounds.width - 8
        definitionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        scrollView.documentView = definitionLabel
        addSubview(scrollView)
    }

    func controlTextDidChange(_ obj: Notification) {
        let word = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        if word.count >= 2 {
            lookupWord(word)
        } else {
            clearDefinition()
        }
    }

    private func lookupWord(_ word: String) {
        // Use macOS Dictionary Services
        guard let definition = DCSCopyTextDefinition(nil, word as CFString, CFRangeMake(0, word.count))?.takeRetainedValue() as String? else {
            showNoDefinition(word)
            return
        }

        displayDefinition(word: word, definition: definition)
    }

    private func displayDefinition(word: String, definition: String) {
        wordLabel.stringValue = word.capitalized

        // Parse definition for part of speech and pronunciation
        let lines = definition.components(separatedBy: "\n")

        var partOfSpeech = ""
        var pronunciation = ""
        let mainDefinition = definition

        // Try to extract part of speech and pronunciation
        if let firstLine = lines.first {
            // Look for pronunciation in slashes or pipes
            if let pronMatch = firstLine.range(of: #"\|[^|]+\|"#, options: .regularExpression) {
                pronunciation = String(firstLine[pronMatch]).replacingOccurrences(of: "|", with: "")
            }

            // Look for common parts of speech
            let partsOfSpeech = ["noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection"]
            for pos in partsOfSpeech {
                if firstLine.lowercased().contains(pos) {
                    partOfSpeech = pos
                    break
                }
            }
        }

        partOfSpeechLabel.stringValue = partOfSpeech
        pronunciationLabel.stringValue = pronunciation

        // Format definition
        let formattedDef = formatDefinition(mainDefinition)
        definitionLabel.stringValue = formattedDef

        // Resize definition label to fit content
        let maxWidth = scrollView.bounds.width - 8
        let height = formattedDef.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        ).height + 20

        definitionLabel.frame = NSRect(x: 0, y: 0, width: maxWidth, height: max(height, scrollView.bounds.height))

        // Animate in
        definitionLabel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            definitionLabel.animator().alphaValue = 1
        }
    }

    private func formatDefinition(_ definition: String) -> String {
        var formatted = definition

        // Clean up common formatting issues
        formatted = formatted.replacingOccurrences(of: "  ", with: " ")

        // Add numbering if there are multiple definitions
        let lines = formatted.components(separatedBy: "\n")
        var numberedLines: [String] = []
        var defNumber = 1

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // If line starts with a definition pattern
            if trimmed.first?.isLetter == true && !trimmed.hasPrefix("•") {
                numberedLines.append(trimmed)
            } else {
                numberedLines.append(trimmed)
            }
        }

        return numberedLines.joined(separator: "\n\n")
    }

    private func showNoDefinition(_ word: String) {
        wordLabel.stringValue = word.capitalized
        partOfSpeechLabel.stringValue = ""
        pronunciationLabel.stringValue = ""
        definitionLabel.stringValue = "No definition found."
        definitionLabel.textColor = NSColor.tertiaryLabelColor
    }

    private func clearDefinition() {
        wordLabel.stringValue = ""
        partOfSpeechLabel.stringValue = ""
        pronunciationLabel.stringValue = ""
        definitionLabel.stringValue = "Type a word to see its definition"
        definitionLabel.textColor = NSColor.tertiaryLabelColor
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        inputField.stringValue = ""
        clearDefinition()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscape?()
            return true
        }
        return false
    }
}
