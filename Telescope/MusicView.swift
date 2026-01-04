import Cocoa

class MusicView: NSView {
    private var artworkView: NSImageView!
    private var trackLabel: NSTextField!
    private var artistLabel: NSTextField!
    private var prevButton: NSButton!
    private var playPauseButton: NSButton!
    private var nextButton: NSButton!
    private var progressBar: NSProgressIndicator!
    private var timeLabel: NSTextField!
    private var noMusicLabel: NSTextField!

    private var updateTimer: Timer?
    private var isPlaying: Bool = false

    var onClose: (() -> Void)?
    var onEscape: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        startUpdating()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startUpdating()
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func setupUI() {
        wantsLayer = true

        let padding: CGFloat = 16

        // Album artwork
        artworkView = NSImageView(frame: NSRect(x: padding, y: 16, width: 72, height: 72))
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 8
        artworkView.layer?.masksToBounds = true
        artworkView.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        artworkView.contentTintColor = NSColor.white
        addSubview(artworkView)

        // Track name - Apple style
        trackLabel = NSTextField(labelWithString: "Not Playing")
        trackLabel.frame = NSRect(x: padding + 84, y: 60, width: bounds.width - padding * 2 - 84, height: 22)
        trackLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        trackLabel.textColor = NSColor.labelColor
        trackLabel.lineBreakMode = .byTruncatingTail
        trackLabel.cell?.truncatesLastVisibleLine = true
        addSubview(trackLabel)

        // Artist name - Apple style
        artistLabel = NSTextField(labelWithString: "")
        artistLabel.frame = NSRect(x: padding + 84, y: 42, width: bounds.width - padding * 2 - 84, height: 18)
        artistLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        artistLabel.textColor = NSColor.secondaryLabelColor
        artistLabel.lineBreakMode = .byTruncatingTail
        addSubview(artistLabel)

        // Playback controls
        let buttonY: CGFloat = 14
        let buttonSpacing: CGFloat = 36
        let controlsX = padding + 84

        prevButton = createControlButton(
            frame: NSRect(x: controlsX, y: buttonY, width: 28, height: 28),
            symbol: "backward.fill",
            action: #selector(previousTrack)
        )
        addSubview(prevButton)

        playPauseButton = createControlButton(
            frame: NSRect(x: controlsX + buttonSpacing, y: buttonY, width: 28, height: 28),
            symbol: "play.fill",
            action: #selector(togglePlayPause)
        )
        playPauseButton.contentTintColor = NSColor.controlAccentColor
        addSubview(playPauseButton)

        nextButton = createControlButton(
            frame: NSRect(x: controlsX + buttonSpacing * 2, y: buttonY, width: 28, height: 28),
            symbol: "forward.fill",
            action: #selector(nextTrack)
        )
        addSubview(nextButton)

        // Time label - Apple style
        timeLabel = NSTextField(labelWithString: "")
        timeLabel.frame = NSRect(x: controlsX + buttonSpacing * 3 + 8, y: buttonY + 4, width: 100, height: 18)
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = NSColor.tertiaryLabelColor
        addSubview(timeLabel)

        // No music playing label (hidden by default) - Apple style
        noMusicLabel = NSTextField(labelWithString: "No music playing")
        noMusicLabel.frame = NSRect(x: padding, y: (bounds.height - 20) / 2, width: bounds.width - padding * 2, height: 20)
        noMusicLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        noMusicLabel.textColor = NSColor.secondaryLabelColor
        noMusicLabel.alignment = .center
        noMusicLabel.isHidden = true
        addSubview(noMusicLabel)

        // Set up keyboard monitoring for this view
        setupKeyboardMonitoring()
    }

    private func createControlButton(frame: NSRect, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = ""
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = NSColor.secondaryLabelColor
        button.target = self
        button.action = action

        // Hover effect
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: button,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        return button
    }

    private func setupKeyboardMonitoring() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, !self.isHidden else { return event }

            switch event.keyCode {
            case 123: // Left arrow
                self.previousTrack()
                return nil
            case 124: // Right arrow
                self.nextTrack()
                return nil
            case 49: // Space
                self.togglePlayPause()
                return nil
            case 53: // ESC
                self.onEscape?()
                return nil
            default:
                return event
            }
        }
    }

    func startUpdating() {
        updateNowPlaying()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateNowPlaying() {
        // Try Apple Music first, then Spotify
        if let musicInfo = getMusicInfo(app: "Music") ?? getMusicInfo(app: "Spotify") {
            showMusicInfo(musicInfo)
        } else {
            showNoMusic()
        }
    }

    private func getMusicInfo(app: String) -> (track: String, artist: String, album: String, isPlaying: Bool, position: Double, duration: Double)? {
        let script: String

        if app == "Music" {
            script = """
                tell application "System Events"
                    if not (exists process "Music") then return "NOT_RUNNING"
                end tell
                tell application "Music"
                    if player state is not stopped then
                        set trackName to name of current track
                        set artistName to artist of current track
                        set albumName to album of current track
                        set isPlaying to (player state is playing)
                        set pos to player position
                        set dur to duration of current track
                        return trackName & "|||" & artistName & "|||" & albumName & "|||" & isPlaying & "|||" & pos & "|||" & dur
                    else
                        return "STOPPED"
                    end if
                end tell
            """
        } else {
            script = """
                tell application "System Events"
                    if not (exists process "Spotify") then return "NOT_RUNNING"
                end tell
                tell application "Spotify"
                    if player state is not stopped then
                        set trackName to name of current track
                        set artistName to artist of current track
                        set albumName to album of current track
                        set isPlaying to (player state is playing)
                        set pos to player position
                        set dur to duration of current track
                        return trackName & "|||" & artistName & "|||" & albumName & "|||" & isPlaying & "|||" & pos & "|||" & (dur / 1000)
                    else
                        return "STOPPED"
                    end if
                end tell
            """
        }

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        guard error == nil, let resultString = result.stringValue else { return nil }

        if resultString == "NOT_RUNNING" || resultString == "STOPPED" {
            return nil
        }

        let components = resultString.components(separatedBy: "|||")
        guard components.count >= 6 else { return nil }

        let track = components[0]
        let artist = components[1]
        let album = components[2]
        let isPlaying = components[3] == "true"
        let position = Double(components[4]) ?? 0
        let duration = Double(components[5]) ?? 0

        return (track, artist, album, isPlaying, position, duration)
    }

    private func showMusicInfo(_ info: (track: String, artist: String, album: String, isPlaying: Bool, position: Double, duration: Double)) {
        trackLabel.stringValue = info.track
        artistLabel.stringValue = info.artist
        isPlaying = info.isPlaying

        // Update play/pause button
        let symbol = info.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)

        // Update time label
        let posStr = formatTime(info.position)
        let durStr = formatTime(info.duration)
        timeLabel.stringValue = "\(posStr) / \(durStr)"

        // Try to get album artwork
        getAlbumArtwork()

        // Show controls, hide no music label
        noMusicLabel.isHidden = true
        artworkView.isHidden = false
        trackLabel.isHidden = false
        artistLabel.isHidden = false
        prevButton.isHidden = false
        playPauseButton.isHidden = false
        nextButton.isHidden = false
        timeLabel.isHidden = false
    }

    private func showNoMusic() {
        noMusicLabel.isHidden = false
        artworkView.isHidden = true
        trackLabel.isHidden = true
        artistLabel.isHidden = true
        prevButton.isHidden = true
        playPauseButton.isHidden = true
        nextButton.isHidden = true
        timeLabel.isHidden = true
    }

    private func getAlbumArtwork() {
        let script = """
            tell application "Music"
                if player state is not stopped then
                    try
                        set artworkData to data of artwork 1 of current track
                        return artworkData
                    end try
                end if
            end tell
            return ""
        """

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let appleScript = NSAppleScript(source: script) else { return }

            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)

            if error == nil {
                let data = result.data
                if !data.isEmpty, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        self?.artworkView.image = image
                        self?.artworkView.contentTintColor = nil
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                self?.artworkView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
                self?.artworkView.contentTintColor = NSColor.white
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @objc private func previousTrack() {
        runMusicCommand("previous track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    @objc private func togglePlayPause() {
        runMusicCommand("playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    @objc private func nextTrack() {
        runMusicCommand("next track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateNowPlaying()
        }
    }

    private func runMusicCommand(_ command: String) {
        // Try Music app first, then Spotify
        let musicScript = """
            tell application "System Events"
                if exists process "Music" then
                    tell application "Music" to \(command)
                    return "OK"
                end if
            end tell
            return "NOT_RUNNING"
        """

        if let script = NSAppleScript(source: musicScript) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if result.stringValue == "OK" {
                return
            }
        }

        // Try Spotify
        let spotifyScript = """
            tell application "System Events"
                if exists process "Spotify" then
                    tell application "Spotify" to \(command)
                end if
            end tell
        """

        if let script = NSAppleScript(source: spotifyScript) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    func reset() {
        updateNowPlaying()
    }
}
