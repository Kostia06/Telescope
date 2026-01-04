import Cocoa
import AVFoundation

class TimerView: NSView {
    private var inputField: NSTextField!
    private var displayLabel: NSTextField!
    private var startStopButton: NSButton!
    private var resetButton: NSButton!
    private var presetStackView: NSStackView!

    private var timer: Timer?
    private var remainingSeconds: Int = 0
    private var isRunning = false
    private var audioPlayer: NSSound?

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

    deinit {
        timer?.invalidate()
    }

    private func setupUI() {
        wantsLayer = true

        let padding: CGFloat = 16

        // Timer display - large, prominent
        displayLabel = NSTextField(labelWithString: "00:00")
        displayLabel.frame = NSRect(x: padding, y: 50, width: 120, height: 44)
        displayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 36, weight: .light)
        displayLabel.textColor = NSColor.controlAccentColor
        displayLabel.alignment = .left
        addSubview(displayLabel)

        // Input field for custom time
        inputField = NSTextField(frame: NSRect(x: 140, y: 62, width: 100, height: 24))
        inputField.placeholderString = "5m, 30s, 1h"
        inputField.font = NSFont.systemFont(ofSize: 13)
        inputField.focusRingType = .none
        inputField.isBordered = false
        inputField.drawsBackground = false
        inputField.textColor = NSColor.labelColor
        inputField.target = self
        inputField.action = #selector(inputChanged)
        addSubview(inputField)

        // Start/Stop button
        startStopButton = NSButton(frame: NSRect(x: 250, y: 58, width: 70, height: 28))
        startStopButton.title = "Start"
        startStopButton.bezelStyle = .rounded
        startStopButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        startStopButton.target = self
        startStopButton.action = #selector(toggleTimer)
        addSubview(startStopButton)

        // Reset button
        resetButton = NSButton(frame: NSRect(x: 325, y: 58, width: 60, height: 28))
        resetButton.title = "Reset"
        resetButton.bezelStyle = .rounded
        resetButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        resetButton.contentTintColor = NSColor.secondaryLabelColor
        resetButton.target = self
        resetButton.action = #selector(resetTimer)
        addSubview(resetButton)

        // Preset buttons
        let presets = ["1m", "5m", "10m", "15m", "30m"]
        var presetButtons: [NSButton] = []

        for preset in presets {
            let button = NSButton(title: preset, target: self, action: #selector(presetTapped(_:)))
            button.bezelStyle = .recessed
            button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            button.controlSize = .small
            presetButtons.append(button)
        }

        presetStackView = NSStackView(views: presetButtons)
        presetStackView.orientation = .horizontal
        presetStackView.spacing = 8
        presetStackView.frame = NSRect(x: padding, y: 16, width: bounds.width - padding * 2, height: 24)
        addSubview(presetStackView)
    }

    @objc private func inputChanged() {
        let input = inputField.stringValue
        if let seconds = parseTimeInput(input) {
            remainingSeconds = seconds
            updateDisplay()
        }
    }

    @objc private func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    @objc private func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        updateDisplay()
        startStopButton.title = "Start"
        displayLabel.textColor = NSColor.controlAccentColor
    }

    @objc private func presetTapped(_ sender: NSButton) {
        if let seconds = parseTimeInput(sender.title) {
            remainingSeconds = seconds
            updateDisplay()
            inputField.stringValue = sender.title
        }
    }

    private func startTimer() {
        if remainingSeconds == 0 {
            // Parse input if no time set
            if let seconds = parseTimeInput(inputField.stringValue), seconds > 0 {
                remainingSeconds = seconds
            } else {
                remainingSeconds = 60 // Default 1 minute
            }
        }

        isRunning = true
        startStopButton.title = "Pause"
        displayLabel.textColor = NSColor.systemGreen

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startStopButton.title = "Resume"
        displayLabel.textColor = NSColor.systemOrange
    }

    private func tick() {
        remainingSeconds -= 1
        updateDisplay()

        if remainingSeconds <= 0 {
            timerComplete()
        } else if remainingSeconds <= 10 {
            displayLabel.textColor = NSColor.systemRed
        }
    }

    private func timerComplete() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startStopButton.title = "Start"
        displayLabel.textColor = NSColor.systemRed

        // Play sound
        NSSound.beep()

        // Flash animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            displayLabel.animator().alphaValue = 0.3
        }, completionHandler: { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self?.displayLabel.animator().alphaValue = 1.0
            })
        })

        // Show notification
        showNotification()
    }

    private func showNotification() {
        let notification = NSUserNotification()
        notification.title = "Timer Complete"
        notification.informativeText = "Your timer has finished!"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func updateDisplay() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        displayLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }

    private func parseTimeInput(_ input: String) -> Int? {
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespaces)

        // Try formats: "5m", "30s", "1h", "5m30s", "1:30", "90"
        var totalSeconds = 0

        // Check for colon format (1:30)
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":")
            if parts.count == 2,
               let mins = Int(parts[0]),
               let secs = Int(parts[1]) {
                return mins * 60 + secs
            }
        }

        // Check for h/m/s format
        let pattern = #"(\d+)\s*(h|m|s)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = regex.matches(in: trimmed, range: range)

            for match in matches {
                if let valueRange = Range(match.range(at: 1), in: trimmed),
                   let unitRange = Range(match.range(at: 2), in: trimmed) {
                    let value = Int(trimmed[valueRange]) ?? 0
                    let unit = String(trimmed[unitRange]).lowercased()

                    switch unit {
                    case "h": totalSeconds += value * 3600
                    case "m": totalSeconds += value * 60
                    case "s": totalSeconds += value
                    default: break
                    }
                }
            }

            if totalSeconds > 0 {
                return totalSeconds
            }
        }

        // Try plain number (assume seconds if < 10, minutes otherwise)
        if let number = Int(trimmed) {
            return number < 10 ? number * 60 : number
        }

        return nil
    }

    func focusTextField() {
        window?.makeFirstResponder(inputField)
    }

    func reset() {
        resetTimer()
        inputField.stringValue = ""
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscape?()
        } else if event.keyCode == 36 { // Enter
            if !isRunning && remainingSeconds == 0 {
                inputChanged()
            }
            toggleTimer()
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
