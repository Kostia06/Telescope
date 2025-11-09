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
            let maxResults = 100
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
                currentDir,
                "/Documents",
                "/Downloads",
                "/Desktop",
                "/Developer",
                "/Projects",
            ]

            // Approximate fuzzy matching (lenient, like fzf)
            func fuzzyMatch(_ pattern: String, _ text: String, isPath: Bool = false) -> (matches: Bool, score: Int) {
                let patternLower = pattern.lowercased()
                let textLower = text.lowercased()

                // Exact substring match gets highest score
                if textLower.contains(patternLower) {
                    return (true, 2000)
                }

                // Approximate fuzzy matching: characters in order but very lenient
                var patternIndex = patternLower.startIndex
                var score = 0
                var lastMatchIndex = -1
                var consecutiveCount = 0

                for (index, char) in textLower.enumerated() {
                    if patternIndex < patternLower.endIndex && char == patternLower[patternIndex] {
                        if lastMatchIndex == index - 1 {
                            consecutiveCount += 1
                            score += 10 + consecutiveCount * 2 // Big bonus for consecutive matches
                        } else {
                            consecutiveCount = 0
                            score += 2 // Small penalty for gaps
                        }
                        lastMatchIndex = index
                        patternIndex = patternLower.index(after: patternIndex)
                    }
                }

                // Very lenient - match if we got most of the pattern
                let matchedChars = patternLower.distance(from: patternLower.startIndex, to: patternIndex)
                let requiredMatch = isPath ? Int(ceil(Double(patternLower.count) * 0.6)) : patternLower.count
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

                    // Skip hidden files but allow dotfiles in home directory
                    if fileName.hasPrefix(".") {
                        if ignoredDirectories.contains(fileName) {
                            enumerator.skipDescendants()
                            continue
                        }
                        // Allow dotfiles in home directory (like .vimrc, .zshrc)
                        if fileURL.path.hasPrefix(self.homeDirectory) &&
                           fileURL.deletingLastPathComponent().path == self.homeDirectory {
                            // Allow it
                        } else {
                            continue
                        }
                    }

                    // Skip ignored directories
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                       resourceValues.isDirectory == true {
                        if ignoredDirectories.contains(fileName) {
                            enumerator.skipDescendants()
                            continue
                        }
                    }

                    // Match against both filename and path
                    let relativePath = fileURL.path.replacingOccurrences(of: self.homeDirectory + "/", with: "")

                    // Try matching filename first
                    var matchResult = fuzzyMatch(query, fileName, isPath: false)

                    // If no match on filename, try the full path (for searches like "documents/projects")
                    if !matchResult.matches {
                        matchResult = fuzzyMatch(query, relativePath, isPath: true)
                    } else {
                        // Boost filename matches
                        matchResult.score += 500
                    }

                    if matchResult.matches {
                        var score = matchResult.score

                        // Boost score for files in current directory
                        if fileURL.path.hasPrefix(currentDir) {
                            score += 800
                        }

                        // Boost score for code files
                        let fileExtension = fileURL.pathExtension.lowercased()
                        if codeExtensions.contains(fileExtension) {
                            score += 150
                        }

                        // Boost score for shorter paths (closer to root)
                        let depth = fileURL.pathComponents.count
                        score -= depth

                        scoredResults.append((
                            command: Command.fileCommand(path: fileURL.path),
                            score: score
                        ))
                    }

                    // Limit search depth
                    if fileURL.pathComponents.count > searchPath.components(separatedBy: "/").count + 6 {
                        enumerator.skipDescendants()
                    }
                }
            }

            // Sort by score and take top results
            scoredResults.sort { $0.score > $1.score }
            results = scoredResults.prefix(maxResults).map { $0.command }

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    private func setupCommands() {
        commands = [
            // Vim-style Commands
            Command(name: ":vsplit", description: "Open vertical split in Vim", icon: "rectangle.split.2x1") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim -c 'vsplit'"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":split", description: "Open horizontal split in Vim", icon: "rectangle.split.1x2") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim -c 'split'"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":tabnew", description: "Open new tab in Vim", icon: "square.stack") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim -c 'tabnew'"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":term", description: "Open terminal in Vim", icon: "terminal") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim -c 'terminal'"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },

            // File Operation Commands
            Command(name: ":touch", description: "Create new file", icon: "doc.badge.plus") {
                self.promptForFileName { fileName in
                    guard !fileName.isEmpty else { return }
                    let path = "\(FileManager.default.currentDirectoryPath)/\(fileName)"
                    FileManager.default.createFile(atPath: path, contents: nil)
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
            },
            Command(name: ":mkdir", description: "Create new directory", icon: "folder.badge.plus") {
                self.promptForFileName { dirName in
                    guard !dirName.isEmpty else { return }
                    let path = "\(FileManager.default.currentDirectoryPath)/\(dirName)"
                    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                }
            },
            Command(name: ":rm", description: "Remove file or directory", icon: "trash") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "rm -i "
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":mv", description: "Move/rename file", icon: "arrow.right.doc.on.clipboard") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "mv "
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":cp", description: "Copy file", icon: "doc.on.doc") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "cp "
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },

            // Yabai Commands
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
                let script = """
                tell application "Terminal"
                    do script "yabai --restart-service"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },

            // System Commands
            Command(name: ":terminal", description: "Launch Terminal app", icon: "terminal") {
                NSWorkspace.shared.launchApplication("Terminal")
            },
            Command(name: ":lock", description: "Lock your Mac", icon: "lock") {
                let task = Process()
                task.launchPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
                task.arguments = ["-suspend"]
                task.launch()
            }, 
            Command(name: ":sleep", description: "Put Mac to sleep", icon: "moon.zzz") {
                let task = Process()
                task.launchPath = "/usr/bin/pmset"
                task.arguments = ["sleepnow"]
                task.launch()
            },
            Command(name: ":screenshot", description: "Take a screenshot", icon: "camera") {
                let task = Process()
                task.launchPath = "/usr/sbin/screencapture"
                task.arguments = ["-i"]
                task.launch()
            },

            // Vim editor commands
            Command(name: ":vim", description: "Open file in Vim (Terminal)", icon: "terminal.fill") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":nvim", description: "Open file in Neovim", icon: "chevron.left.forwardslash.chevron.right") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "nvim"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },
            Command(name: ":vimrc", description: "Edit ~/.vimrc", icon: "doc.text") {
                let script = """
                tell application "Terminal"
                    activate
                    do script "vim ~/.vimrc"
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            },

            // Quick access
            Command(name: ":finder", description: "Open Finder", icon: "folder") {
                NSWorkspace.shared.launchApplication("Finder")
            },
            Command(name: ":safari", description: "Open Safari", icon: "safari") {
                NSWorkspace.shared.launchApplication("Safari")
            },
            Command(name: ":quit", description: "Quit Telescope", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        ]
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
        // Empty search returns no results (user should type to see files)
        if searchText.isEmpty {
            return []
        }

        // Command mode: starts with ":"
        if searchText.hasPrefix(":") {
            return commands.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description.lowercased().contains(searchText.lowercased())
            }
        }

        // File search mode: no results yet, will be populated by async search
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
