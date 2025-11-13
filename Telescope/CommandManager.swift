import Cocoa
import Fuse

class CommandManager {
    private(set) var commands: [Command] = []
    private var appSearchQueue = DispatchQueue(label: "com.telescope.appsearch", qos: .userInitiated)
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    private weak var drawingModeController: DrawingModeController?
    private weak var soundModeController: SoundModeController?

    // Search cancellation tracking
    private var currentSearchID: Int = 0
    private let searchLock = NSLock()

    // Fuse instance for fuzzy matching (thread-safe as serial queue)
    private let fuse: Fuse

    init(drawingModeController: DrawingModeController? = nil, soundModeController: SoundModeController? = nil) {
        self.drawingModeController = drawingModeController
        self.soundModeController = soundModeController

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
            Command(name: ":yabai focus-left", description: "Focus window to the left", icon: "arrow.left.square") {
                self.executeYabaiCommand(["-m", "window", "--focus", "west"])
            },
            Command(name: ":yabai focus-right", description: "Focus window to the right", icon: "arrow.right.square") {
                self.executeYabaiCommand(["-m", "window", "--focus", "east"])
            },
            Command(name: ":yabai focus-up", description: "Focus window above", icon: "arrow.up.square") {
                self.executeYabaiCommand(["-m", "window", "--focus", "north"])
            },
            Command(name: ":yabai focus-down", description: "Focus window below", icon: "arrow.down.square") {
                self.executeYabaiCommand(["-m", "window", "--focus", "south"])
            },
            Command(name: ":yabai move-left", description: "Move window to the left", icon: "arrow.left.circle") {
                self.executeYabaiCommand(["-m", "window", "--swap", "west"])
            },
            Command(name: ":yabai move-right", description: "Move window to the right", icon: "arrow.right.circle") {
                self.executeYabaiCommand(["-m", "window", "--swap", "east"])
            },
            Command(name: ":yabai move-up", description: "Move window up", icon: "arrow.up.circle") {
                self.executeYabaiCommand(["-m", "window", "--swap", "north"])
            },
            Command(name: ":yabai move-down", description: "Move window down", icon: "arrow.down.circle") {
                self.executeYabaiCommand(["-m", "window", "--swap", "south"])
            },
            Command(name: ":yabai toggle-float", description: "Toggle floating window", icon: "rectangle.3.group") {
                self.executeYabaiCommand(["-m", "window", "--toggle", "float"])
            },
            Command(name: ":yabai fullscreen", description: "Toggle fullscreen mode", icon: "arrow.up.left.and.arrow.down.right") {
                self.executeYabaiCommand(["-m", "window", "--toggle", "zoom-fullscreen"])
            },
            Command(name: ":yabai toggle-split", description: "Toggle split direction", icon: "rectangle.split.2x1") {
                self.executeYabaiCommand(["-m", "window", "--toggle", "split"])
            },
            Command(name: ":yabai rotate", description: "Rotate windows 90° clockwise", icon: "arrow.clockwise") {
                self.executeYabaiCommand(["-m", "space", "--rotate", "90"])
            },
            Command(name: ":yabai balance", description: "Balance window sizes", icon: "rectangle.grid.2x2") {
                self.executeYabaiCommand(["-m", "space", "--balance"])
            },
            Command(name: ":yabai next-space", description: "Focus next space", icon: "arrow.forward") {
                self.executeYabaiCommand(["-m", "space", "--focus", "next"])
            },
            Command(name: ":yabai prev-space", description: "Focus previous space", icon: "arrow.backward") {
                self.executeYabaiCommand(["-m", "space", "--focus", "prev"])
            },
            Command(name: ":yabai restart", description: "Restart Yabai service", icon: "arrow.triangle.2.circlepath") {
                self.executeYabaiCommand(["--restart-service"])
            },
            Command(name: ":term", description: "Launch Terminal app", icon: "terminal") {
                NSWorkspace.shared.launchApplication("WezTerm")
            },
            Command(name: ":edit", description: "Open selected file in Neovim", icon: "pencil") {
                // This action is handled in SpotlightViewController
            },
            Command(name: ":draw", description: "Enter drawing mode", icon: "pencil.tip.crop.circle") {
                self.drawingModeController?.toggleDrawingMode()
            },
            Command(name: ":sound", description: "Control app volumes", icon: "speaker.wave.3") {
                self.soundModeController?.toggleSoundMode()
            },
            Command(name: ":q", description: "Quit Telescope", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        ]
    }

    func openInNeovim(filePath: String) {
        let script = """
        tell application "WezTerm"
            create window with default profile
            tell current session of current window
                write text "nvim '\(filePath)'"
            end tell
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("Error executing AppleScript: \(error)")
            }
        }
    }
    
    private func executeYabaiCommand(_ arguments: [String]) {
        let task = Process()
        task.launchPath = "/usr/local/bin/yabai"
        task.arguments = arguments

        // Try alternate path if not found
        if !FileManager.default.fileExists(atPath: "/usr/local/bin/yabai") {
            task.launchPath = "/opt/homebrew/bin/yabai"
        }

        do {
            try task.run()
        } catch {
            print("Error executing yabai command: \(error)")
        }
    }
    
    func filterCommands(with searchText: String) -> [Command] {
        if searchText.isEmpty {
            return []
        }

        if searchText.hasPrefix(":") {
            let commandSearch = searchText.lowercased()
            return commands.filter {
                $0.name.lowercased().contains(commandSearch) && $0.name != ":edit"
            }
        }

        return []
    }

    private func promptForFileName(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Enter name"
            alert.informativeText = "Please enter the file/directory name:"
            alert.alertStyle = .informational

            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            textField.placeholderString = "filename"
            alert.accessoryView = textField

            alert.addButton(withTitle: "Create")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completion(textField.stringValue)
            }
        }
    }
}
