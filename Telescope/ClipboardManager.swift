import Cocoa

class ClipboardManager {
    static let shared = ClipboardManager()

    private let maxHistoryItems = 5
    private var history: [ClipboardItem] = []
    private let defaults = UserDefaults.standard
    private let historyKey = "com.telescope.clipboard.history"
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var monitorTimer: Timer?

    private init() {
        loadHistory()
        setupClipboardMonitoring()
    }

    // MARK: - Clipboard Monitoring

    private func setupClipboardMonitoring() {
        // Poll clipboard change count - this is reliable and doesn't interfere
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentCount = NSPasteboard.general.changeCount
            if currentCount != self.lastChangeCount {
                print("DEBUG: Clipboard changed (count: \(self.lastChangeCount) -> \(currentCount))")
                self.lastChangeCount = currentCount
                self.captureClipboard()
            }
        }
    }

    private func captureClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else {
            print("DEBUG: No string in clipboard")
            return
        }
        guard !string.isEmpty else {
            print("DEBUG: Clipboard is empty")
            return
        }

        print("DEBUG: Captured clipboard: \(string.prefix(50))...")

        // Don't add if it's the same as the most recent item
        if let lastItem = history.first, lastItem.content == string {
            print("DEBUG: Duplicate entry, skipping")
            return
        }

        let item = ClipboardItem(content: string, timestamp: Date())
        history.insert(item, at: 0)

        print("DEBUG: Added to history. Total items: \(history.count)")

        // Keep only maxHistoryItems
        if history.count > maxHistoryItems {
            history.removeLast()
        }

        saveHistory()
    }

    // MARK: - History Management

    func getHistory() -> [ClipboardItem] {
        return history
    }

    func paste(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }

    func removeItem(_ item: ClipboardItem) {
        history.removeAll { $0.content == item.content && $0.timestamp == item.timestamp }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        let encoded = history.map { item -> [String: Any] in
            ["content": item.content, "timestamp": item.timestamp.timeIntervalSince1970]
        }
        defaults.set(encoded, forKey: historyKey)
    }

    private func loadHistory() {
        guard let encoded = defaults.array(forKey: historyKey) as? [[String: Any]] else { return }

        history = encoded.compactMap { dict in
            guard let content = dict["content"] as? String,
                  let timestamp = dict["timestamp"] as? TimeInterval else {
                return nil
            }
            return ClipboardItem(content: content, timestamp: Date(timeIntervalSince1970: timestamp))
        }
    }
}

struct ClipboardItem {
    let content: String
    let timestamp: Date

    var shortContent: String {
        // Truncate and remove newlines for display
        let singleLine = content.replacingOccurrences(of: "\n", with: " ")
        let maxLength = 60

        if singleLine.count > maxLength {
            let endIndex = singleLine.index(singleLine.startIndex, offsetBy: maxLength)
            return String(singleLine[..<endIndex]) + "..."
        }
        return singleLine
    }
}
