import Cocoa
import IOKit.ps

class SystemInfoView: NSView {
    private var batteryIcon: NSImageView!
    private var batteryLabel: NSTextField!
    private var batteryBar: NSProgressIndicator!
    private var cpuLabel: NSTextField!
    private var memoryLabel: NSTextField!
    private var diskLabel: NSTextField!
    private var uptimeLabel: NSTextField!
    private var networkLabel: NSTextField!

    private var updateTimer: Timer?

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
        let rowHeight: CGFloat = 22
        var y = bounds.height - 28

        // Battery section
        batteryIcon = NSImageView(frame: NSRect(x: padding, y: y, width: 20, height: 20))
        batteryIcon.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: nil)
        batteryIcon.contentTintColor = NSColor.systemGreen
        addSubview(batteryIcon)

        batteryLabel = createLabel(x: padding + 28, y: y, width: 80)
        batteryLabel.stringValue = "Battery"
        addSubview(batteryLabel)

        batteryBar = NSProgressIndicator(frame: NSRect(x: padding + 110, y: y + 4, width: 100, height: 12))
        batteryBar.style = .bar
        batteryBar.isIndeterminate = false
        batteryBar.minValue = 0
        batteryBar.maxValue = 100
        addSubview(batteryBar)

        // CPU
        y -= rowHeight
        let cpuIcon = NSImageView(frame: NSRect(x: padding, y: y, width: 20, height: 20))
        cpuIcon.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        cpuIcon.contentTintColor = NSColor.secondaryLabelColor
        addSubview(cpuIcon)

        cpuLabel = createLabel(x: padding + 28, y: y, width: 200)
        addSubview(cpuLabel)

        // Memory
        y -= rowHeight
        let memIcon = NSImageView(frame: NSRect(x: padding, y: y, width: 20, height: 20))
        memIcon.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil)
        memIcon.contentTintColor = NSColor.secondaryLabelColor
        addSubview(memIcon)

        memoryLabel = createLabel(x: padding + 28, y: y, width: 250)
        addSubview(memoryLabel)

        // Disk
        y -= rowHeight
        let diskIcon = NSImageView(frame: NSRect(x: padding, y: y, width: 20, height: 20))
        diskIcon.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: nil)
        diskIcon.contentTintColor = NSColor.secondaryLabelColor
        addSubview(diskIcon)

        diskLabel = createLabel(x: padding + 28, y: y, width: 300)
        addSubview(diskLabel)

        // Uptime (right column)
        let rightX: CGFloat = 250

        y = bounds.height - 28
        let uptimeIcon = NSImageView(frame: NSRect(x: rightX, y: y, width: 20, height: 20))
        uptimeIcon.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        uptimeIcon.contentTintColor = NSColor.secondaryLabelColor
        addSubview(uptimeIcon)

        uptimeLabel = createLabel(x: rightX + 28, y: y, width: 180)
        addSubview(uptimeLabel)

        // Network
        y -= rowHeight
        let netIcon = NSImageView(frame: NSRect(x: rightX, y: y, width: 20, height: 20))
        netIcon.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)
        netIcon.contentTintColor = NSColor.secondaryLabelColor
        addSubview(netIcon)

        networkLabel = createLabel(x: rightX + 28, y: y, width: 180)
        addSubview(networkLabel)
    }

    private func createLabel(x: CGFloat, y: CGFloat, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.frame = NSRect(x: x, y: y, width: width, height: 20)
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = NSColor.labelColor
        return label
    }

    private func startUpdating() {
        updateInfo()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateInfo()
        }
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateInfo() {
        updateBattery()
        updateCPU()
        updateMemory()
        updateDisk()
        updateUptime()
        updateNetwork()
    }

    private func updateBattery() {
        guard let powerInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSources = IOPSCopyPowerSourcesList(powerInfo)?.takeRetainedValue() as? [CFTypeRef],
              let source = powerSources.first,
              let description = IOPSGetPowerSourceDescription(powerInfo, source)?.takeUnretainedValue() as? [String: Any] else {
            batteryLabel.stringValue = "No Battery"
            batteryBar.isHidden = true
            return
        }

        let percent = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

        batteryLabel.stringValue = "\(percent)%"
        batteryBar.doubleValue = Double(percent)
        batteryBar.isHidden = false

        // Update icon and color
        let iconName: String
        let color: NSColor

        if isCharging {
            iconName = "battery.100.bolt"
            color = .systemGreen
        } else if percent <= 10 {
            iconName = "battery.0"
            color = .systemRed
        } else if percent <= 20 {
            iconName = "battery.25"
            color = .systemOrange
        } else if percent <= 50 {
            iconName = "battery.50"
            color = .systemYellow
        } else if percent <= 75 {
            iconName = "battery.75"
            color = .labelColor
        } else {
            iconName = "battery.100"
            color = .systemGreen
        }

        batteryIcon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        batteryIcon.contentTintColor = color
    }

    private func updateCPU() {
        // Get CPU usage using host_statistics
        var cpuInfo: host_cpu_load_info_data_t = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let user = Double(cpuInfo.cpu_ticks.0)
            let system = Double(cpuInfo.cpu_ticks.1)
            let idle = Double(cpuInfo.cpu_ticks.2)
            let nice = Double(cpuInfo.cpu_ticks.3)
            let total = user + system + idle + nice
            let usage = ((user + system) / total) * 100

            cpuLabel.stringValue = String(format: "CPU: %.1f%%", usage)
        } else {
            cpuLabel.stringValue = "CPU: --"
        }
    }

    private func updateMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed

            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedGB = Double(used) / 1_073_741_824
            let totalGB = Double(totalMemory) / 1_073_741_824
            let percent = (Double(used) / Double(totalMemory)) * 100

            memoryLabel.stringValue = String(format: "RAM: %.1f / %.0f GB (%.0f%%)", usedGB, totalGB, percent)
        } else {
            memoryLabel.stringValue = "RAM: --"
        }
    }

    private func updateDisk() {
        let fileURL = URL(fileURLWithPath: "/")

        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = total - available
                let usedGB = Double(used) / 1_000_000_000
                let totalGB = Double(total) / 1_000_000_000
                let percent = (Double(used) / Double(total)) * 100

                diskLabel.stringValue = String(format: "Disk: %.0f / %.0f GB (%.0f%%)", usedGB, totalGB, percent)
            }
        } catch {
            diskLabel.stringValue = "Disk: --"
        }
    }

    private func updateUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        if sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 {
            let uptime = Date().timeIntervalSince1970 - Double(boottime.tv_sec)

            let days = Int(uptime) / 86400
            let hours = (Int(uptime) % 86400) / 3600
            let minutes = (Int(uptime) % 3600) / 60

            if days > 0 {
                uptimeLabel.stringValue = String(format: "Up: %dd %dh %dm", days, hours, minutes)
            } else if hours > 0 {
                uptimeLabel.stringValue = String(format: "Up: %dh %dm", hours, minutes)
            } else {
                uptimeLabel.stringValue = String(format: "Up: %dm", minutes)
            }
        } else {
            uptimeLabel.stringValue = "Up: --"
        }
    }

    private func updateNetwork() {
        // Get current WiFi SSID
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport")
        process.arguments = ["-I"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if let ssidMatch = output.range(of: #"SSID: (.+)"#, options: .regularExpression) {
                    let ssidLine = String(output[ssidMatch])
                    let ssid = ssidLine.replacingOccurrences(of: "SSID: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    networkLabel.stringValue = ssid
                    return
                }
            }
        } catch {
            // Ignore
        }

        networkLabel.stringValue = "Not Connected"
    }

    func reset() {
        updateInfo()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}
