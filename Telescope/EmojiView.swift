import Cocoa

class EmojiView: NSView, NSTextFieldDelegate {
    private var inputField: NSTextField!
    private var emojiScrollView: NSScrollView!
    private var emojiContainer: NSView!
    private var selectedIndex: Int = 0
    private var emojiButtons: [NSButton] = []
    private var filteredEmojis: [(emoji: String, name: String)] = []

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?

    // Common emojis with keywords
    private let emojiData: [(emoji: String, keywords: [String])] = [
        ("😀", ["smile", "happy", "grin", "face"]),
        ("😂", ["laugh", "cry", "tears", "lol", "funny"]),
        ("🥹", ["emotional", "touched", "grateful"]),
        ("😊", ["blush", "happy", "smile", "shy"]),
        ("😍", ["love", "heart", "eyes", "adore"]),
        ("🥰", ["love", "hearts", "affection"]),
        ("😘", ["kiss", "love", "blow"]),
        ("😎", ["cool", "sunglasses", "awesome"]),
        ("🤔", ["think", "thinking", "hmm", "wonder"]),
        ("😢", ["sad", "cry", "tear"]),
        ("😭", ["cry", "sob", "sad", "tears"]),
        ("😤", ["angry", "frustrated", "steam"]),
        ("😡", ["angry", "mad", "rage"]),
        ("🤯", ["mind", "blown", "explode", "shock"]),
        ("😱", ["scream", "shock", "scared"]),
        ("🥳", ["party", "celebrate", "birthday"]),
        ("😴", ["sleep", "tired", "zzz"]),
        ("🤢", ["sick", "nauseous", "green"]),
        ("🤮", ["vomit", "sick", "puke"]),
        ("🤧", ["sneeze", "sick", "cold"]),
        ("👍", ["thumbs", "up", "yes", "good", "ok", "like"]),
        ("👎", ["thumbs", "down", "no", "bad", "dislike"]),
        ("👏", ["clap", "applause", "bravo"]),
        ("🙌", ["hands", "celebrate", "raise", "hooray"]),
        ("🤝", ["handshake", "deal", "agree"]),
        ("🙏", ["pray", "please", "thanks", "hope"]),
        ("💪", ["muscle", "strong", "flex", "power"]),
        ("❤️", ["heart", "love", "red"]),
        ("🧡", ["heart", "orange", "love"]),
        ("💛", ["heart", "yellow", "love"]),
        ("💚", ["heart", "green", "love"]),
        ("💙", ["heart", "blue", "love"]),
        ("💜", ["heart", "purple", "love"]),
        ("🖤", ["heart", "black", "love"]),
        ("💔", ["broken", "heart", "sad"]),
        ("💯", ["hundred", "perfect", "score"]),
        ("✨", ["sparkle", "magic", "star", "shine"]),
        ("🔥", ["fire", "hot", "lit", "flame"]),
        ("⭐", ["star", "favorite", "rating"]),
        ("🌟", ["star", "glow", "shine"]),
        ("💫", ["dizzy", "star", "magic"]),
        ("🎉", ["party", "celebrate", "confetti"]),
        ("🎊", ["confetti", "party", "celebrate"]),
        ("🎁", ["gift", "present", "birthday"]),
        ("🎂", ["cake", "birthday", "celebrate"]),
        ("🍕", ["pizza", "food", "cheese"]),
        ("🍔", ["burger", "food", "hamburger"]),
        ("🍟", ["fries", "food", "french"]),
        ("🌮", ["taco", "food", "mexican"]),
        ("🍣", ["sushi", "food", "japanese"]),
        ("🍺", ["beer", "drink", "cheers"]),
        ("🍷", ["wine", "drink", "glass"]),
        ("☕", ["coffee", "drink", "cafe"]),
        ("🍵", ["tea", "drink", "cup"]),
        ("🚀", ["rocket", "launch", "space", "fast"]),
        ("✈️", ["plane", "airplane", "travel", "flight"]),
        ("🚗", ["car", "drive", "vehicle"]),
        ("🏠", ["home", "house", "building"]),
        ("💻", ["laptop", "computer", "work"]),
        ("📱", ["phone", "mobile", "iphone"]),
        ("⌨️", ["keyboard", "type", "computer"]),
        ("🖥️", ["computer", "desktop", "monitor"]),
        ("📧", ["email", "mail", "message"]),
        ("📝", ["note", "write", "memo"]),
        ("📅", ["calendar", "date", "schedule"]),
        ("⏰", ["clock", "alarm", "time"]),
        ("🔔", ["bell", "notification", "alert"]),
        ("🔒", ["lock", "secure", "password"]),
        ("🔑", ["key", "unlock", "password"]),
        ("💡", ["idea", "light", "bulb", "think"]),
        ("🎵", ["music", "note", "song"]),
        ("🎶", ["music", "notes", "song"]),
        ("🎤", ["microphone", "sing", "karaoke"]),
        ("🎧", ["headphones", "music", "listen"]),
        ("📸", ["camera", "photo", "picture"]),
        ("🎬", ["movie", "film", "action"]),
        ("🎮", ["game", "controller", "play"]),
        ("🏆", ["trophy", "winner", "champion"]),
        ("🥇", ["gold", "medal", "first", "winner"]),
        ("⚽", ["soccer", "football", "ball"]),
        ("🏀", ["basketball", "ball", "sport"]),
        ("🌈", ["rainbow", "color", "pride"]),
        ("☀️", ["sun", "sunny", "weather", "bright"]),
        ("🌙", ["moon", "night", "sleep"]),
        ("⛈️", ["storm", "thunder", "rain"]),
        ("❄️", ["snow", "cold", "winter", "freeze"]),
        ("🌊", ["wave", "ocean", "water", "sea"]),
        ("🌸", ["flower", "cherry", "blossom", "spring"]),
        ("🌺", ["flower", "hibiscus", "tropical"]),
        ("🌻", ["sunflower", "flower", "yellow"]),
        ("🍀", ["clover", "luck", "lucky", "irish"]),
        ("🐶", ["dog", "puppy", "pet"]),
        ("🐱", ["cat", "kitty", "pet"]),
        ("🦊", ["fox", "animal", "cute"]),
        ("🐻", ["bear", "animal", "teddy"]),
        ("🐼", ["panda", "bear", "animal"]),
        ("🦁", ["lion", "animal", "king"]),
        ("🐮", ["cow", "animal", "moo"]),
        ("🐷", ["pig", "animal", "oink"]),
        ("🐸", ["frog", "animal", "ribbit"]),
        ("🦋", ["butterfly", "insect", "pretty"]),
        ("✅", ["check", "done", "complete", "yes"]),
        ("❌", ["x", "no", "wrong", "cancel"]),
        ("⚠️", ["warning", "alert", "caution"]),
        ("💬", ["speech", "comment", "message", "chat"]),
        ("👀", ["eyes", "look", "see", "watching"]),
        ("🤷", ["shrug", "whatever", "idk"]),
        ("🙄", ["eye", "roll", "annoyed"]),
        ("😏", ["smirk", "sly", "suggestive"]),
        ("🤓", ["nerd", "glasses", "geek"]),
        ("🧠", ["brain", "think", "smart", "mind"]),
        ("💀", ["skull", "dead", "death"]),
        ("👻", ["ghost", "boo", "halloween"]),
        ("🤖", ["robot", "bot", "android"]),
        ("👽", ["alien", "ufo", "space"]),
        ("🦄", ["unicorn", "magic", "fantasy"]),
        ("🐉", ["dragon", "fantasy", "fire"])
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        showAllEmojis()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        showAllEmojis()
    }

    private func setupUI() {
        wantsLayer = true

        let padding: CGFloat = 12

        // Search input
        inputField = NSTextField(frame: NSRect(x: padding, y: bounds.height - 36, width: bounds.width - padding * 2, height: 24))
        inputField.placeholderString = "Search emoji..."
        inputField.font = NSFont.systemFont(ofSize: 13)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = NSColor.labelColor
        inputField.delegate = self
        addSubview(inputField)

        // Emoji scroll view
        emojiScrollView = NSScrollView(frame: NSRect(x: padding, y: 8, width: bounds.width - padding * 2, height: bounds.height - 48))
        emojiScrollView.hasVerticalScroller = true
        emojiScrollView.hasHorizontalScroller = false
        emojiScrollView.autohidesScrollers = true
        emojiScrollView.drawsBackground = false
        emojiScrollView.borderType = .noBorder

        emojiContainer = NSView()
        emojiScrollView.documentView = emojiContainer

        addSubview(emojiScrollView)
    }

    func controlTextDidChange(_ obj: Notification) {
        let query = inputField.stringValue.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            showAllEmojis()
        } else {
            filterEmojis(query)
        }
    }

    private func showAllEmojis() {
        filteredEmojis = emojiData.map { ($0.emoji, $0.keywords.first ?? "") }
        displayEmojis()
    }

    private func filterEmojis(_ query: String) {
        filteredEmojis = emojiData.compactMap { item in
            let matches = item.keywords.contains { keyword in
                keyword.contains(query) || query.contains(keyword)
            }
            if matches {
                return (item.emoji, item.keywords.first ?? "")
            }
            return nil
        }
        displayEmojis()
    }

    private func displayEmojis() {
        // Clear existing buttons
        emojiButtons.forEach { $0.removeFromSuperview() }
        emojiButtons.removeAll()

        let buttonSize: CGFloat = 36
        let spacing: CGFloat = 4
        let columns = Int((emojiScrollView.bounds.width - spacing) / (buttonSize + spacing))
        let rows = (filteredEmojis.count + columns - 1) / columns

        let containerHeight = CGFloat(rows) * (buttonSize + spacing) + spacing
        emojiContainer.frame = NSRect(x: 0, y: 0, width: emojiScrollView.bounds.width, height: max(containerHeight, emojiScrollView.bounds.height))

        for (index, item) in filteredEmojis.enumerated() {
            let col = index % columns
            let row = index / columns

            let x = CGFloat(col) * (buttonSize + spacing) + spacing
            let y = containerHeight - CGFloat(row + 1) * (buttonSize + spacing)

            let button = NSButton(frame: NSRect(x: x, y: y, width: buttonSize, height: buttonSize))
            button.title = item.emoji
            button.font = NSFont.systemFont(ofSize: 22)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.target = self
            button.action = #selector(emojiTapped(_:))
            button.tag = index

            // Add hover effect
            button.wantsLayer = true
            button.layer?.cornerRadius = 6

            let trackingArea = NSTrackingArea(
                rect: button.bounds,
                options: [.mouseEnteredAndExited, .activeInKeyWindow],
                owner: button,
                userInfo: ["index": index]
            )
            button.addTrackingArea(trackingArea)

            emojiContainer.addSubview(button)
            emojiButtons.append(button)
        }

        selectedIndex = 0
        updateSelection()
    }

    @objc private func emojiTapped(_ sender: NSButton) {
        guard sender.tag < filteredEmojis.count else { return }
        let emoji = filteredEmojis[sender.tag].emoji
        copyEmoji(emoji)
    }

    private func copyEmoji(_ emoji: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)

        // Visual feedback
        let feedbackLabel = NSTextField(labelWithString: "Copied \(emoji)")
        feedbackLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        feedbackLabel.textColor = NSColor.labelColor
        feedbackLabel.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2)
        feedbackLabel.wantsLayer = true
        feedbackLabel.layer?.cornerRadius = 4
        feedbackLabel.alignment = .center
        feedbackLabel.frame = NSRect(x: (bounds.width - 100) / 2, y: bounds.height / 2 - 12, width: 100, height: 24)
        feedbackLabel.alphaValue = 0
        addSubview(feedbackLabel)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            feedbackLabel.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    feedbackLabel.animator().alphaValue = 0
                }, completionHandler: {
                    feedbackLabel.removeFromSuperview()
                })
            }
        })
    }

    private func updateSelection() {
        for (index, button) in emojiButtons.enumerated() {
            if index == selectedIndex {
                button.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
            } else {
                button.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        inputField.stringValue = ""
        showAllEmojis()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onEscape?()
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Copy selected emoji
            if selectedIndex < filteredEmojis.count {
                copyEmoji(filteredEmojis[selectedIndex].emoji)
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveRight(_:)) {
            if selectedIndex < filteredEmojis.count - 1 {
                selectedIndex += 1
                updateSelection()
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveLeft(_:)) {
            if selectedIndex > 0 {
                selectedIndex -= 1
                updateSelection()
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let columns = Int((emojiScrollView.bounds.width - 4) / 40)
            if selectedIndex + columns < filteredEmojis.count {
                selectedIndex += columns
                updateSelection()
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let columns = Int((emojiScrollView.bounds.width - 4) / 40)
            if selectedIndex - columns >= 0 {
                selectedIndex -= columns
                updateSelection()
            }
            return true
        }
        return false
    }
}
