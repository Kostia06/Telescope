# Telescope

A powerful macOS launcher and productivity application inspired by Spotlight. Telescope combines fast application search, file discovery, and creative tools like drawing and annotations in a unified interface.

## Features

- **Fast Application Launcher** - Search and launch applications with intelligent fuzzy matching
- **File Search** - Quickly find files across your system with score-based ranking
- **Command Palette** - Execute custom commands with `:` prefix
  - `:screenshot` - Capture screenshots
  - `:record` - Record screen sessions
  - `:draw` - Full-screen drawing and annotation mode
  - `:q` - Quick access commands
- **Drawing & Annotation** - Full-screen drawing capabilities with:
  - Free-hand drawing
  - Shapes (rectangles, circles, arrows)
  - Text annotations
  - Multiple colors and eraser tools
  - Selection and undo functionality
- **Menu Command Extraction** - Access application menu bar commands directly
- **Global Hotkey** - Trigger with `Cmd+Space` for instant access
- **Accessibility Integration** - Deep macOS system integration for menu reading and application control

## Tech Stack

### Language & Framework
- **Swift** (5.0+) - 100% native Swift codebase
- **Cocoa/AppKit** - macOS native GUI framework
- **Foundation** - Core system utilities

### Dependencies
- **[HotKey](https://github.com/soffes/HotKey)** (`>=0.2.0`) - Global keyboard shortcut management
- **[Fuse](https://github.com/krisk/fuse-swift)** (`>=1.4.0`) - Fuzzy string matching for intelligent search scoring
- **[Files](https://github.com/JohnSundell/Files)** (`>=4.0.0`) - File system abstraction

### Build System
- **Xcode** with Swift Package Manager for dependency management
- **macOS 10+** target platform

### System Frameworks
- **AppKit** - Application and window management
- **Foundation** - Core utilities and file system access
- **Accessibility Framework** - Menu item extraction and accessibility features
- **UniformTypeIdentifiers** - File type detection and icon resolution
- **AppleScript** - Application control and menu execution

## Architecture

### Core Components

#### Application Entry (`AppDelegate.swift`)
- Application lifecycle management
- Global `Cmd+Space` hotkey registration
- Runs as background accessory application

#### Search Engine (`CommandManager.swift`)
- Fuzzy matching using Fuse library
- Searches applications from `/Applications`, `/System/Applications`, and `~/Applications`
- Thread-safe concurrent searches with cancellation support
- Intelligent score-based result ranking:
  1. Exact matches
  2. Starts-with matches
  3. Fuzzy matches

#### UI Components
- **SpotlightViewController** - Main search interface with real-time results
- **SpotlightWindowController** - Floating panel window with animations
- **CommandCellView** & **CommandRowView** - Result display with hover effects
- **DrawingView** - Full-featured drawing canvas (~1,100 lines)
- **CommandHoldMenuView** - Menu command display

#### Advanced Features
- **DrawingModeController** - Drawing overlay management
- **CommandHoldMenuController** - Application menu extraction via Accessibility API

### Design Patterns
- **MVC Architecture** - Clear separation of models, views, and controllers
- **Delegation** - Event handling and data sourcing
- **Concurrency** - Background GCD queues for non-blocking searches
- **Observer Pattern** - Keyboard and window event monitoring

## Project Structure

```
Telescope/
├── Telescope/
│   ├── AppDelegate.swift                 # Application entry point
│   ├── CommandManager.swift              # Search engine and command execution
│   ├── Command.swift                     # Command data model
│   ├── SpotlightViewController.swift     # Main search UI
│   ├── SpotlightWindowController.swift   # Floating window management
│   ├── CommandCellView.swift             # Result cell styling
│   ├── CommandRowView.swift              # Result row styling
│   ├── DrawingView.swift                 # Drawing/annotation implementation
│   ├── DrawingModeController.swift       # Drawing mode management
│   ├── CommandHoldMenuController.swift   # Menu extraction
│   ├── CommandHoldMenuView.swift         # Menu display
│   ├── Info.plist                        # Application configuration
│   ├── Assets.xcassets                   # App icons and resources
│   └── Base.lproj/                       # Localization files
├── Telescope.xcodeproj/                  # Xcode project configuration
└── README.md                             # This file
```

## Development

### Building
1. Open `Telescope.xcodeproj` in Xcode
2. Select the target platform (macOS)
3. Build with `Cmd+B` or Product → Build

### Dependencies
Dependencies are managed via Swift Package Manager and are automatically resolved when building in Xcode.

### Key Implementation Details

**Search Algorithm**
- Fuzzy matching powered by Fuse library
- Results scored and ranked for relevance
- File search debounced at 150ms to prevent excessive system calls
- Background thread execution prevents UI blocking

**Drawing Implementation**
- Custom NSView subclass with mouse and keyboard event handling
- Support for multiple drawing tools and properties
- Full undo/redo functionality
- Color palette and shape libraries

**Keyboard Navigation**
- Arrow keys to navigate results
- Enter to execute selected command
- Escape to close search panel
- Full accessibility support via AppleScript

## System Integration

Telescope integrates deeply with macOS:
- Registers as an accessory application (runs in background)
- Global hotkey via Carbon events
- Reads application menu structure through Accessibility APIs
- Executes AppleScript commands for menu item activation
- Works across multiple spaces and desktops

## Permissions

The application requires the following macOS permissions:
- **Accessibility** - For reading application menus and menu bar items
- **AppleScript** - For controlling other applications

These are declared in `Info.plist` with appropriate usage descriptions.

## Recent Development

Recent improvements include:
- Search accuracy enhancements
- Neovim integration for file opening
- Window behavior optimization
- UI refinements and visual effects

---

**Status**: Active development

**Platform**: macOS 10+

**Language**: Swift 5.0+

**License**: [Add your license here]
