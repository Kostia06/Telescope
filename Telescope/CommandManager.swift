import Cocoa

class CommandManager {
    private(set) var commands: [Command] = []
    private var fileSearchQueue = DispatchQueue(label: "com.telescope.filesearch", qos: .userInitiated)
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

    init() {
        setupCommands()
    }

    func searchFiles(query: String, completion: @escaping ([Command]) -> Void) {
        fileSearchQueue.async { [weak self] in
            guard let self = self else { return }

            var results: [Command] = []
            let maxResults = 15
            let currentDir = FileManager.default.currentDirectoryPath

            // Directories to ignore (like .gitignore patterns)
            let ignoredDirectories = [
                ".git", ".next", "node_modules", ".vscode", ".idea",
                ".DS_Store", "dist", "build", ".cache", ".gradle",
                ".venv", "venv", "__pycache__", ".pytest_cache",
                "target", ".svn", ".hg", "vendor", ".terraform"
            ]

            // File extensions to prioritize
            let codeExtensions = [
                "swift", "js", "ts", "tsx", "jsx", "py", "go", "rs",
                "java", "c", "cpp", "h", "hpp", "cs", "rb", "php",
                "html", "css", "scss", "json", "yaml", "yml", "md",
                "txt", "sh", "zsh", "vim"
            ]

            // Search in current directory first, then expand
            let searchPaths = [
                "\(homeDirectory)/Documents",
                "\(homeDirectory)/Downloads",
                "\(homeDirectory)/Desktop",
                "\(homeDirectory)/Developer",
                homeDirectory,
                currentDir
            ]

            // Approximate fuzzy matching (more strict)
            func fuzzyMatch(_ pattern: String, _ text: String, isPath: Bool = false) -> (matches: Bool, score: Int) {
                let patternLower = pattern.lowercased()
                let textLower = text.lowercased()

                if textLower.contains(patternLower) {
                    return (true, 10000)
                }

                var patternIndex = patternLower.startIndex
                var score = 0
                var lastMatchIndex = -1
                var consecutiveCount = 0

                for (index, char) in textLower.enumerated() {
                    if patternIndex < patternLower.endIndex && char == patternLower[patternIndex] {
                        if lastMatchIndex == index - 1 {
                            consecutiveCount += 1
                            score += 40 + consecutiveCount * 15
                        } else {
                            consecutiveCount = 0
                            score += 5
                        }
                        lastMatchIndex = index
                        patternIndex = patternLower.index(after: patternIndex)
                    }
                }

                let matchedChars = patternLower.distance(from: patternLower.startIndex, to: patternIndex)
                let requiredMatch = isPath ? Int(ceil(Double(patternLower.count) * 0.6)) : Int(ceil(Double(patternLower.count) * 0.9))
                let matches = matchedChars >= requiredMatch

                return (matches, matches ? score : 0)
            }

            var scoredResults: [(command: Command, score: Int)] = []

            for searchPath in searchPaths {
                if scoredResults.count >= maxResults * 2 { break }

                guard let enumerator = FileManager.default.enumerator(
                    at: URL(fileURLWithPath: searchPath),
                    includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                    options: [.skipsPackageDescendants]
                ) else { continue }

                for case let fileURL as URL in enumerator {
                    if scoredResults.count >= maxResults * 2 { break }

                    let fileName = fileURL.lastPathComponent

                    if fileName.hasPrefix(".") {
                        if ignoredDirectories.contains(fileName) {
                            enumerator.skipDescendants()
                            continue
                        }
                        if fileURL.path.hasPrefix(self.homeDirectory) &&
                           fileURL.deletingLastPathComponent().path == self.homeDirectory {
                        } else {
                            continue
                        }
                    }
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                       resourceValues.isDirectory == true {
                        if ignoredDirectories.contains(fileName) {
                            enumerator.skipDescendants()
                            continue
                        }
                    }

                    let relativePath = fileURL.path.replacingOccurrences(of: self.homeDirectory + "/", with: "")
                    var matchResult = fuzzyMatch(query, fileName, isPath: false)

                    if !matchResult.matches {
                        matchResult = fuzzyMatch(query, relativePath, isPath: true)
                    } else {
                        matchResult.score += 1000
                    }

                    if matchResult.matches {
                        var score = matchResult.score

                        if fileURL.path.hasPrefix(currentDir) {
                            score += 1200
                        }

                        let fileExtension = fileURL.pathExtension.lowercased()
                        if codeExtensions.contains(fileExtension) {
                            score += 200
                        }

                        let depth = fileURL.pathComponents.count
                        score -= depth

                        scoredResults.append((
                            command: Command.fileCommand(path: fileURL.path),
                            score: score
                        ))
                    }

                    if fileURL.pathComponents.count > searchPath.components(separatedBy: "/").count + 7 {
                        enumerator.skipDescendants()
                    }
                }
            }

            scoredResults.sort { $0.score > $1.score }
            results = scoredResults.prefix(maxResults).map { $0.command }

            DispatchQueue.main.async {
                completion(results)
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
