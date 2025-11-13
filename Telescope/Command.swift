import Foundation
import UniformTypeIdentifiers
import Cocoa

enum SearchResultType {
    case file(path: String)
    case app(path: String)
    case command
}

struct Command {
    let name: String
    let description: String
    let icon: String
    let customIcon: NSImage?
    let type: SearchResultType
    let action: () -> Void

    init(name: String, description: String, icon: String, customIcon: NSImage? = nil, type: SearchResultType = .command, action: @escaping () -> Void) {
        self.name = name
        self.description = description
        self.icon = icon
        self.customIcon = customIcon
        self.type = type
        self.action = action
    }

    static func fileCommand(path: String) -> Command {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        let parentPath = url.deletingLastPathComponent().path

        // Determine icon and if it's a directory
        let icon: String
        var isDirectory = false

        if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey]) {
            if resourceValues.isDirectory == true {
                isDirectory = true
                icon = "folder.fill"
            } else if let contentType = resourceValues.contentType {
                icon = Self.iconForContentType(contentType)
            } else {
                icon = "doc.fill"
            }
        } else {
            icon = "doc.fill"
        }

        return Command(
            name: fileName,
            description: parentPath,
            icon: icon,
            type: .file(path: path)
        ) {
            // Open file or folder
            if isDirectory {
                // Open folder in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
            } else {
                // Open file in default application
                NSWorkspace.shared.open(url)
            }
        }
    }

    static func appCommand(path: String, name: String) -> Command {
        let url = URL(fileURLWithPath: path)

        // Get the actual app icon
        let appIcon = NSWorkspace.shared.icon(forFile: path)
        appIcon.size = NSSize(width: 32, height: 32)

        return Command(
            name: name,
            description: "Application",
            icon: "app.fill",
            customIcon: appIcon,
            type: .app(path: path)
        ) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func iconForContentType(_ contentType: UTType) -> String {
        if contentType.conforms(to: .image) {
            return "photo.fill"
        } else if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return "film.fill"
        } else if contentType.conforms(to: .audio) {
            return "music.note"
        } else if contentType.conforms(to: .pdf) {
            return "doc.richtext.fill"
        } else if contentType.conforms(to: .sourceCode) {
            return "chevron.left.forwardslash.chevron.right"
        } else if contentType.conforms(to: .text) {
            return "doc.text.fill"
        } else if contentType.conforms(to: .archive) {
            return "doc.zipper"
        } else {
            return "doc.fill"
        }
    }
}
