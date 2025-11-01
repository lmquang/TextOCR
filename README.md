# TextOCR - macOS Screenshot Text Recognition App

A lightweight macOS menu bar application that captures screenshots, performs OCR text recognition, and automatically copies the extracted text to your clipboard.

## Features

- 📸 **Screenshot Capture**: Select any region of your screen with a visual overlay
- 🔤 **OCR Text Recognition**: Powered by Apple Vision Framework for accurate text extraction
- 📋 **Auto Clipboard**: Extracted text is automatically copied to clipboard
- ⚡ **Menu Bar App**: Lightweight app that lives in your menu bar
- 🎯 **Native macOS**: Built with Swift and modern macOS APIs

## Status: MVP 0 ✅

This is the initial MVP (Minimum Viable Product) focused on core functionality. See [Implementation Status](docs/sessions/202510311543-macos-ocr-screenshot-app/implementation/STATUS.md) for details.

## Requirements

- macOS 11.0 or later
- Xcode 15.0 or later (for building)
- Screen Recording permission

## Installation

### Quick Install (Recommended)

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd TextOCR
   ```

2. Run the build and install script:
   ```bash
   ./scripts/build-app.sh
   ```

3. Grant Screen Recording permission when prompted:
   - System Preferences → Privacy & Security → Privacy → Screen Recording
   - Enable checkbox for TextOCR

### Build from Source (Manual)

1. Clone and open the project:
   ```bash
   git clone <repository-url>
   cd TextOCR
   open TextOCR.xcodeproj
   ```

2. Build and run in Xcode (⌘R)

3. Grant permissions as needed

## Usage

1. Launch the app - a menu bar icon (document with viewfinder) will appear
2. Click the menu bar icon
3. Select "Capture Text"
4. Click and drag to select the screen region containing text
5. Release to capture - text will be automatically extracted and copied to clipboard
6. Press ESC to cancel selection
7. Paste (⌘V) the extracted text anywhere

## Architecture

The app follows a clean service-based architecture:

```
TextOCR/
├── App/
│   ├── AppDelegate.swift         # App lifecycle management
│   ├── MenuBarController.swift   # Menu bar UI and interactions
│   └── Info.plist                # App configuration
├── Services/
│   ├── ClipboardService.swift    # Clipboard operations
│   ├── OCRService.swift          # Vision Framework OCR
│   └── ScreenCaptureService.swift # ScreenCaptureKit integration
└── Coordinators/
    └── CaptureCoordinator.swift  # Workflow orchestration
```

### Key Technologies

- **ScreenCaptureKit**: Modern macOS screen capture API
- **Vision Framework**: Apple's native OCR engine
- **AppKit**: Menu bar app implementation
- **Swift 5.0**: Modern Swift with async/await

## Performance

MVP 0 includes comprehensive performance instrumentation. The goal is to achieve end-to-end latency of <0.3 seconds from screenshot to clipboard.

Current implementation includes timing logs for:
- Screenshot capture duration
- OCR processing time
- Clipboard copy time
- Total workflow time

## Development

### Project Structure

See [MVP 0 Architecture](docs/sessions/202510311543-macos-ocr-screenshot-app/planning/mvp0-architecture.md) for detailed architecture documentation.

### Build Scripts

Two scripts are available in the `scripts/` directory:

**Build and install app:**
```bash
./scripts/build-app.sh
```
- Clean build in Release configuration
- Interactive prompts for installation
- Copies to /Applications
- Optional cleanup of build artifacts

**Setup app icon:**
```bash
./scripts/setup-icon.sh
```
- Generates all icon sizes from source
- Updates AppIcon asset catalog
- Prepares icons for Xcode

See [scripts/README.md](scripts/README.md) for detailed documentation.

### Manual Building

```bash
# Debug build
xcodebuild -scheme TextOCR -configuration Debug build

# Release build
xcodebuild -scheme TextOCR -configuration Release build
```

## Recent Updates

### Global Hotkey Support ✅
- Default hotkey: ⇧⌘2 (Shift+Cmd+2)
- Customizable in Settings window
- Works system-wide from any app
- Menu bar shows current hotkey

### Enhanced Capture UX ✅
- Crosshair cursor during selection
- Real-time dimensions display
- Professional selection overlay

### Known Limitations

Current version does not include:
- ❌ Screenshot history
- ❌ Multi-language OCR configuration
- ❌ Advanced error handling
- ❌ Export options

These features are planned for future iterations.

## Roadmap

### Next Steps
1. ✅ MVP 0: Core functionality (screenshot → OCR → clipboard)
2. ⏳ Performance baseline measurement
3. ⏳ Global hotkey support
4. ⏳ Hotkey customization
5. ⏳ Performance optimization (<0.3s target)
6. ⏳ Advanced features (history, settings, etc.)

## Contributing

This project follows a structured development workflow:
- Planning and architecture documentation in `docs/sessions/`
- Test-driven development approach
- Performance-first mindset

## License

[To be determined]

## Acknowledgments

- Apple Vision Framework for OCR capabilities
- Apple ScreenCaptureKit for modern screen capture
- macOS AppKit for menu bar functionality
