import Cocoa
import CoreAudio

// Custom window that accepts key events even when borderless
class SoundWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class SoundModeController {
    private var overlayWindow: SoundWindow?
    private var soundView: SoundModeView?
    private var isActive = false

    func toggleSoundMode() {
        if isActive {
            exitSoundMode()
        } else {
            enterSoundMode()
        }
    }

    private func enterSoundMode() {
        guard let screen = NSScreen.main else { return }

        let window = SoundWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        window.isOpaque = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let soundView = SoundModeView(frame: window.contentView!.bounds)
        soundView.controller = self
        window.contentView = soundView

        self.soundView = soundView
        self.overlayWindow = window
        self.isActive = true

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Ensure the sound view becomes first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(soundView)
        }
    }

    private func exitSoundMode() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        soundView = nil
        isActive = false
    }
}
