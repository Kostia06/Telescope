import Cocoa
import Fuse

class CommandManager {
    private(set) var commands: [Command] = []
    private var appSearchQueue = DispatchQueue(label: "com.telescope.appsearch", qos: .userInitiated)
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    private weak var drawingModeController: DrawingModeController?

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

        setupCommands()
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
                        scoredAppResults.append((
                            command: Command.appCommand(path: appURL.path, name: appName),
                            score: matchResult.score
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
            Command(name: ":q", description: "Quit Telescope", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        ]
    }

    private func takeScreenshot() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"

        // Generate timestamp for filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot_\(timestamp).png"

        // Get Downloads folder path
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let screenshotPath = downloadsURL.appendingPathComponent(filename).path

        task.arguments = ["-i", "-x", screenshotPath]

        do {
            try task.run()
        } catch {
            print("Error taking screenshot: \(error)")
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
    
    func filterCommands(with searchText: String) -> [Command] {
        if searchText.isEmpty {
            return []
        }

        if searchText.hasPrefix(":") {
            let commandSearch = searchText.lowercased()
            return commands.filter {
                $0.name.lowercased().contains(commandSearch)
            }
        }

        return []
    }
}
