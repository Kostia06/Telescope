import Cocoa
import CoreAudio
import AVFoundation

struct AppAudioInfo {
    let appName: String
    let appIcon: NSImage?
    let processID: pid_t
    let audioDeviceID: AudioDeviceID
    var volume: Float
}

class SoundModeView: NSView {
    weak var controller: SoundModeController?
    private var appsWithAudio: [AppAudioInfo] = []
    private var containerView: NSVisualEffectView?
    private var scrollView: NSScrollView?
    private var contentStackView: NSStackView?
    private var refreshTimer: Timer?
    private var volumeUpdateTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        detectAppsWithAudio()
        startRefreshTimer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        detectAppsWithAudio()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        volumeUpdateTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var canBecomeKeyView: Bool {
        return true
    }

    private func setupView() {
        wantsLayer = true

        // Create main container with visual effect
        let containerWidth: CGFloat = 600
        let containerHeight: CGFloat = 500
        let containerX = (bounds.width - containerWidth) / 2
        let containerY = (bounds.height - containerHeight) / 2

        let visualEffect = NSVisualEffectView(frame: NSRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true

        // Add shadow for depth
        visualEffect.layer?.shadowColor = NSColor.black.cgColor
        visualEffect.layer?.shadowOpacity = 0.5
        visualEffect.layer?.shadowOffset = NSSize(width: 0, height: -8)
        visualEffect.layer?.shadowRadius = 24

        addSubview(visualEffect)
        containerView = visualEffect

        // Title
        let titleLabel = NSTextField(labelWithString: "App Volume Control")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 30, y: containerHeight - 60, width: containerWidth - 60, height: 32)
        titleLabel.alignment = .center
        visualEffect.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "System volume control for media apps")
        subtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 30, y: containerHeight - 85, width: containerWidth - 60, height: 16)
        subtitleLabel.alignment = .center
        visualEffect.addSubview(subtitleLabel)

        // Separator
        let separator = NSBox(frame: NSRect(x: 30, y: containerHeight - 100, width: containerWidth - 60, height: 1))
        separator.boxType = .separator
        separator.fillColor = .separatorColor
        visualEffect.addSubview(separator)

        // Scroll view for apps
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: containerWidth - 40, height: containerHeight - 200))
        scrollView?.hasVerticalScroller = true
        scrollView?.drawsBackground = false
        scrollView?.borderType = .noBorder
        scrollView?.scrollerStyle = .overlay
        visualEffect.addSubview(scrollView!)

        // Stack view for app controls
        contentStackView = NSStackView(frame: NSRect(x: 0, y: 0, width: containerWidth - 40, height: 100))
        contentStackView?.orientation = .vertical
        contentStackView?.spacing = 12
        contentStackView?.alignment = .leading
        contentStackView?.distribution = .gravityAreas
        scrollView?.documentView = contentStackView

        // ESC hint
        let escHintX = (containerWidth - 100) / 2

        let escIcon = NSImageView(frame: NSRect(x: escHintX, y: 35, width: 22, height: 22))
        escIcon.image = NSImage(systemSymbolName: "escape", accessibilityDescription: nil)
        escIcon.contentTintColor = .tertiaryLabelColor
        escIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        visualEffect.addSubview(escIcon)

        let exitLabel = NSTextField(labelWithString: "to exit")
        exitLabel.font = NSFont.systemFont(ofSize: 13)
        exitLabel.textColor = .tertiaryLabelColor
        exitLabel.frame = NSRect(x: escHintX + 28, y: 37, width: 60, height: 18)
        exitLabel.isBordered = false
        exitLabel.isEditable = false
        exitLabel.backgroundColor = .clear
        visualEffect.addSubview(exitLabel)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC key
            controller?.toggleSoundMode()
        default:
            super.keyDown(with: event)
        }
    }

    private func startRefreshTimer() {
        // Refresh app list every 5 seconds to reduce UI jitter
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.detectAppsWithAudio()
        }
    }

    private func detectAppsWithAudio() {
        var newApps: [AppAudioInfo] = []

        // Get system audio device
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        // Get current system volume
        let systemVolume = getSystemVolume()

        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications

        // Filter to only apps that might be using audio
        for app in runningApps {
            // Skip background apps and system processes
            guard app.activationPolicy == .regular,
                  let appName = app.localizedName,
                  let bundleURL = app.bundleURL else {
                continue
            }

            // Only show well-known media apps or apps likely to use audio
            let mediaAppNames = ["Music", "Spotify", "Safari", "Chrome", "Firefox", "VLC", "QuickTime", "Zoom", "Discord", "Slack", "FaceTime", "YouTube"]
            let isLikelyMediaApp = mediaAppNames.contains { appName.contains($0) }

            if !isLikelyMediaApp {
                continue
            }

            // Get app icon
            let appIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            appIcon.size = NSSize(width: 32, height: 32)

            let appInfo = AppAudioInfo(
                appName: appName,
                appIcon: appIcon,
                processID: app.processIdentifier,
                audioDeviceID: defaultOutputDeviceID,
                volume: systemVolume
            )
            newApps.append(appInfo)
        }

        // Sort by app name
        newApps.sort { $0.appName < $1.appName }

        // Check if apps list has changed (by comparing app names and process IDs)
        let hasChanged = newApps.count != appsWithAudio.count ||
            zip(newApps, appsWithAudio).contains { $0.appName != $1.appName || $0.processID != $1.processID }

        // Only update UI if the app list has changed
        if hasChanged {
            DispatchQueue.main.async { [weak self] in
                self?.appsWithAudio = newApps
                self?.updateAppControls()
            }
        }
    }

    private func getVolumeForApp(processID: pid_t) -> Float {
        // This is a simplified version - actual per-app volume control
        // requires using CoreAudio APIs with audio session management
        // For now, we'll return system volume
        return getSystemVolume()
    }

    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        guard status == noErr else { return 0.5 }

        var volume: Float32 = 0.5
        propertySize = UInt32(MemoryLayout<Float32>.size)

        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        propertyAddress.mElement = kAudioObjectPropertyElementMain

        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )

        return volume
    }

    private func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )

        guard status == noErr else { return }

        var newVolume = volume
        propertySize = UInt32(MemoryLayout<Float32>.size)

        propertyAddress.mSelector = kAudioDevicePropertyVolumeScalar
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        propertyAddress.mElement = kAudioObjectPropertyElementMain

        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            propertySize,
            &newVolume
        )
    }

    private func updateAppControls() {
        guard let stackView = contentStackView else { return }

        // Remove old views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Add controls for each app
        for (index, app) in appsWithAudio.enumerated() {
            let appControl = createAppVolumeControl(for: app, index: index)
            stackView.addArrangedSubview(appControl)
        }

        // Update content size
        let contentHeight = CGFloat(appsWithAudio.count) * 72 + CGFloat(max(0, appsWithAudio.count - 1)) * 12
        contentStackView?.frame = NSRect(x: 0, y: 0, width: scrollView?.frame.width ?? 560, height: contentHeight)
    }

    private func createAppVolumeControl(for app: AppAudioInfo, index: Int) -> NSView {
        let controlView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 60))
        controlView.wantsLayer = true
        controlView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        controlView.layer?.cornerRadius = 10

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 16, y: 14, width: 32, height: 32))
        iconView.image = app.appIcon
        controlView.addSubview(iconView)

        // App name
        let nameLabel = NSTextField(labelWithString: app.appName)
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.frame = NSRect(x: 60, y: 23, width: 200, height: 18)
        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.backgroundColor = .clear
        controlView.addSubview(nameLabel)

        // Volume slider
        let slider = NSSlider(frame: NSRect(x: 280, y: 18, width: 220, height: 24))
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.doubleValue = Double(app.volume)
        slider.target = self
        slider.action = #selector(volumeSliderChanged(_:))
        slider.tag = index
        slider.isContinuous = true
        controlView.addSubview(slider)

        // Volume percentage label
        let volumeLabel = NSTextField(labelWithString: "\(Int(app.volume * 100))%")
        volumeLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        volumeLabel.textColor = .secondaryLabelColor
        volumeLabel.frame = NSRect(x: 510, y: 24, width: 40, height: 16)
        volumeLabel.alignment = .right
        volumeLabel.isBordered = false
        volumeLabel.isEditable = false
        volumeLabel.backgroundColor = .clear
        volumeLabel.tag = 1000 + index // Special tag for volume label
        controlView.addSubview(volumeLabel)

        return controlView
    }

    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        let index = sender.tag
        guard index < appsWithAudio.count else { return }

        let newVolume = Float(sender.doubleValue)

        // Update the app's volume
        appsWithAudio[index].volume = newVolume

        // Update the volume label immediately for responsive UI
        if let label = contentStackView?.arrangedSubviews[index].subviews.first(where: { $0.tag == 1000 + index }) as? NSTextField {
            label.stringValue = "\(Int(newVolume * 100))%"
        }

        // Debounce volume updates to reduce lag
        volumeUpdateTimer?.invalidate()
        volumeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.setSystemVolume(newVolume)
        }
    }
}
