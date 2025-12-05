import Cocoa
import Fuse
import UserNotifications
// ClipboardManager is part of the same target and will be available

class CommandManager {
    private(set) var commands: [Command] = []
    private var appSearchQueue = DispatchQueue(label: "com.telescope.appsearch", qos: .userInitiated)
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    private weak var drawingModeController: DrawingModeController?
    private var notesWindowController: NotesWindowController?

    // Search cancellation tracking
    private var currentSearchID: Int = 0
    private let searchLock = NSLock()

    // Fuse instance for fuzzy matching (thread-safe as serial queue)
    private let fuse: Fuse

    init(drawingModeController: DrawingModeController? = nil) {
        self.drawingModeController = drawingModeController

        // Configure Fuse for optimal fuzzy searching
        self.fuse = Fuse(
            location: 0,           // Prefer matches at start
            distance: 100,         // Search distance
            threshold: 0.4         // Lower = stricter matching (0.0-1.0)
        )

        // Initialize notes window
        self.notesWindowController = NotesWindowController()

        setupCommands()
        requestNotificationPermissions()
    }

    private func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }

    func searchFiles(query: String, completion: @escaping ([Command]) -> Void) {
        // Increment search ID to cancel previous searches
        searchLock.lock()
        currentSearchID += 1
        let searchID = currentSearchID
        searchLock.unlock()

        // Run search on background queue
        appSearchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            // Check if this search is still current
            func isCurrentSearch() -> Bool {
                self.searchLock.lock()
                let isCurrent = searchID == self.currentSearchID
                self.searchLock.unlock()
                return isCurrent
            }

            let maxAppResults = 20

            // Fuzzy match using Fuse.swift (safe to use self.fuse on serial queue)
            func fuzzyMatch(_ pattern: String, _ text: String) -> (matches: Bool, score: Int) {
                let patternLower = pattern.lowercased()
                let textLower = text.lowercased()

                // Exact match gets highest priority
                if textLower == patternLower {
                    return (true, 1000000)
                }

                // Starts with pattern - very high priority
                if textLower.hasPrefix(patternLower) {
                    return (true, 500000)
                }

                // Use Fuse for fuzzy matching (accessing self.fuse safely on serial queue)
                if let result = self.fuse.search(patternLower, in: textLower) {
                    // Fuse returns score from 0.0 (perfect) to 1.0 (poor)
                    // Convert to our scoring system: lower Fuse score = higher our score
                    let fuseScore = result.score

                    // Only accept matches below threshold (0.4)
                    if fuseScore <= 0.4 {
                        // Convert Fuse score (0.0-0.4) to our score (100000-10000)
                        // Better matches (lower fuseScore) get higher scores
                        let baseScore = Int((1.0 - fuseScore) * 100000)

                        // Check if it's a substring match for bonus
                        if textLower.contains(patternLower) {
                            if let range = textLower.range(of: patternLower) {
                                let position = textLower.distance(from: textLower.startIndex, to: range.lowerBound)

                                // Earlier position = higher score
                                let positionBonus = max(0, 50000 - (position * 500))

                                // Check word boundary
                                let components = textLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
                                for component in components {
                                    if component == patternLower {
                                        return (true, baseScore + positionBonus + 100000)
                                    }
                                    if component.hasPrefix(patternLower) {
                                        return (true, baseScore + positionBonus + 50000)
                                    }
                                }

                                return (true, baseScore + positionBonus + 20000)
                            }
                        }

                        return (true, baseScore)
                    }
                }

                return (false, 0)
            }

            // Search for apps
            var scoredAppResults: [(command: Command, score: Int)] = []
            let appSearchPaths = [
                "/Applications",
                "/System/Applications",
                "\(self.homeDirectory)/Applications"
            ]

            for appPath in appSearchPaths {
                // Check if search was cancelled
                if !isCurrentSearch() {
                    return
                }

                guard let appEnumerator = FileManager.default.enumerator(
                    at: URL(fileURLWithPath: appPath),
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                for case let appURL as URL in appEnumerator {
                    // Check if search was cancelled
                    if !isCurrentSearch() {
                        return
                    }

                    guard appURL.pathExtension == "app" else { continue }

                    let appName = appURL.deletingPathExtension().lastPathComponent
                    let matchResult = fuzzyMatch(query, appName)

                    if matchResult.matches {
                        // Get usage points and add bonus to score
                        let usagePoints = UsageTracker.shared.getUsagePoints(for: appURL.path)

                        // Each usage adds 10,000 points (configurable weight)
                        // This ensures frequently used apps rank higher
                        let usageBonus = usagePoints * 10000
                        let totalScore = matchResult.score + usageBonus

                        scoredAppResults.append((
                            command: Command.appCommand(path: appURL.path, name: appName),
                            score: totalScore
                        ))
                    }
                }
            }

            // Final check before returning results
            if !isCurrentSearch() {
                return
            }

            // Sort by score and limit results
            scoredAppResults.sort { $0.score > $1.score }
            let appResults = scoredAppResults.prefix(maxAppResults).map { $0.command }

            // Only call completion if this search is still current
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.searchLock.lock()
                let isCurrent = searchID == self.currentSearchID
                self.searchLock.unlock()

                if isCurrent {
                    completion(appResults)
                }
            }
        }
    }

    private func setupCommands() {
        commands = [
            Command(name: ":screenshot", description: "Take a screenshot", icon: "camera") {
                self.takeScreenshot()
            },
            Command(name: ":record", description: "Record screen", icon: "video.fill") {
                self.startScreenRecording()
            },
            Command(name: ":draw", description: "Enter drawing mode", icon: "pencil.tip.crop.circle") {
                self.drawingModeController?.toggleDrawingMode()
            },
            Command(name: ":clip", description: "Clipboard history", icon: "clipboard.fill") {
                // This is a placeholder; actual history is shown in filterCommands
            },
            Command(name: ":note", description: "Open notes", icon: "note.text") {
                self.openNotes()
            },
            Command(name: ":notes", description: "Open notes", icon: "note.text") {
                self.openNotes()
            },
            Command(name: ":build", description: "Build and deploy app", icon: "hammer.fill") {
                self.buildAndDeploy()
            },
            Command(name: ":version", description: "Show Telescope version", icon: "info.circle") {
                self.showVersion()
            },
            Command(name: ":q", description: "Quit Telescope", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        ]
    }

    private func takeScreenshot() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        // Copy to clipboard with interactive selection
        task.arguments = ["-i", "-c"]

        task.terminationHandler = { [weak self] process in
            if process.terminationStatus == 0 {
                // Screenshot was taken successfully, show notification
                DispatchQueue.main.async {
                    self?.showNotification(title: "Screenshot Copied", body: "Screenshot has been copied to clipboard")
                }
            }
        }

        do {
            try task.run()
        } catch {
            print("Error taking screenshot: \(error)")
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }

    private func startScreenRecording() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", "Screenshot"]

        do {
            try task.run()
        } catch {
            print("Error starting screen recording: \(error)")
        }
    }

    private func buildAndDeploy() {
        appSearchQueue.async {
            let buildTask = Process()
            buildTask.launchPath = "/usr/bin/xcodebuild"

            let projectPath = "/Users/kostiailn/Documents/PROJECTS/Telescope"
            let buildPath = "\(self.homeDirectory)/Documents/Projects/Telescope/build"

            buildTask.arguments = [
                "-scheme", "Telescope",
                "-configuration", "Release",
                "-derivedDataPath", buildPath
            ]

            buildTask.currentDirectoryPath = projectPath

            let pipe = Pipe()
            buildTask.standardOutput = pipe
            buildTask.standardError = pipe

            do {
                try buildTask.run()
                buildTask.waitUntilExit()

                let status = buildTask.terminationStatus
                DispatchQueue.main.async {
                    if status == 0 {
                        print("✓ Build succeeded")
                    } else {
                        print("✗ Build failed with status: \(status)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error building app: \(error)")
                }
            }
        }
    }

    private func showVersion() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Telescope"
            alert.informativeText = "Version \(version) (Build \(build))"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func openNotes() {
        DispatchQueue.main.async {
            self.notesWindowController?.showWindow()
        }
    }

    private func viewNote(note: Note) {
        DispatchQueue.main.async {
            self.notesWindowController?.showWindow()
            self.notesWindowController?.selectNote(id: note.id)
        }
    }

    func filterCommands(with searchText: String) -> [Command] {
        if searchText.isEmpty {
            return []
        }

        if searchText.hasPrefix(":") {
            let commandSearch = searchText.lowercased()
            print("DEBUG: filterCommands called with: \(searchText)")

            // Special handling for clipboard history
            if commandSearch == ":clip" || commandSearch == ":c" {
                print("DEBUG: Filtering for clip command")
                let historyItems = ClipboardManager.shared.getHistory()
                print("DEBUG: Clipboard history has \(historyItems.count) items")
                for (index, item) in historyItems.enumerated() {
                    print("DEBUG:   [\(index)]: \(item.shortContent)")
                }

                let results = historyItems.enumerated().map { (index, item) in
                    Command(
                        name: item.shortContent,
                        description: "⏎ Options  •  \(formatDate(item.timestamp))",
                        icon: "doc.on.clipboard",
                        type: .clipboardItem(item: item)
                    ) {
                        // Default action: paste item
                        print("DEBUG: Pasting item \(index + 1): \(item.shortContent)")
                        ClipboardManager.shared.paste(item: item)
                    }
                }

                print("DEBUG: Returning \(results.count) clipboard items")
                return results
            }

            return commands.filter {
                $0.name.lowercased().contains(commandSearch)
            }
        }

        return []
    }

    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: now)

        if let seconds = components.second, seconds < 60 {
            return "just now"
        } else if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m ago"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h ago"
        } else if let days = components.day {
            return "\(days)d ago"
        }
        return "earlier"
    }
}
