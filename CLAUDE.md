# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TextOCR is a macOS menu bar application that captures screenshots, performs OCR text recognition using Apple Vision Framework, and automatically copies extracted text to clipboard. Built with Swift and AppKit, it uses modern macOS APIs including ScreenCaptureKit and Vision Framework.

## Build & Development Commands

### Building the Application

**Quick build and install (recommended):**
```bash
./scripts/build-app.sh
```
This builds in Release mode, optionally copies to /Applications, and cleans up build artifacts.

**Build in Xcode:**
```bash
open TextOCR.xcodeproj
# Then use ⌘B to build, ⌘R to run
```

**Manual builds:**
```bash
# Debug build
xcodebuild -scheme TextOCR -configuration Debug build

# Release build
xcodebuild -scheme TextOCR -configuration Release build
```

**Package dependency:** The project uses KeyboardShortcuts SPM package from sindresorhus. If package resolution fails, add it manually in Xcode via File → Add Package Dependencies.

### Icon Setup

```bash
./scripts/setup-icon.sh
```
Requires source icon at `public/asset/icon.png` (1024x1024 PNG).

## Architecture & Critical Components

### Service-Based Architecture

The app follows a clean separation of concerns:

```
AppDelegate → MenuBarController → CaptureCoordinator → Services
                                        ↓
                    ScreenCaptureService / OCRService / ClipboardService
```

### Core Workflow

1. **Trigger**: Global hotkey (⇧⌘2) or menu bar click → `CaptureCoordinator.startCapture()`
2. **Capture**: `ScreenCaptureService.captureRegion()` shows full-screen overlay with selection UI
3. **OCR**: `OCRService.extractText()` uses Vision Framework's `VNRecognizeTextRequest`
4. **Clipboard**: `ClipboardService.copy()` writes to `NSPasteboard`
5. **Feedback**: `NotificationWindow` shows success/failure

### ScreenCaptureService - Dual-Mode Cursor Architecture

**Critical implementation detail:** The screen capture uses a sophisticated dual-mode approach to handle cursor display across all app contexts (normal apps vs system privileged apps like System Settings).

**Mode 1: Normal Mode (AppKit Cursor Rects)**
- Used when app can become key/active
- Uses standard `NSTrackingArea` with `.activeAlways` + `.inVisibleRect`
- Cursor managed via `resetCursorRects()` and `cursorUpdate(with:)`
- Window level: `.screenSaver` (above menu bar/Dock)

**Mode 2: Fallback Mode (Custom Crosshair Drawing)**
- Activated when app cannot become key (e.g., triggered from System Settings)
- Hides system cursor with `NSCursor.hide()`
- Draws custom crosshair in SelectionView
- Uses `NSEvent.addGlobalMonitorForEvents()` to track mouse (no Accessibility permission needed)
- On first click, attempts activation and switches to normal mode

**Activation Detection:**
After `makeKeyAndOrderFront()`, waits 200ms and checks:
- `NSApp.isActive`
- `window.isKeyWindow`
- `window.occlusionState.contains(.visible)`
- `window.isOnActiveSpace`

If any check fails → enters fallback mode.

**Key Implementation Points:**
- Window uses `disableCursorRects()` before `makeKeyAndOrderFront()` to prevent premature cursor evaluation
- `windowDidBecomeKey` delegate calls `enableCursorRects()` + `invalidateCursorRects()`
- Guard timer (16ms/60fps) forces crosshair until `cursorUpdate` confirms AppKit ownership
- Selection window must override both `canBecomeKey` and `canBecomeMain` to return `true`

### Memory Management Patterns

**Critical: Avoid retain cycles in closure-heavy code**
- `ScreenCaptureService` → `SelectionWindowController` → `SelectionWindow`
- Use `[weak self]` in all async closures and callbacks
- `onFinished` callback cleared in `windowWillClose` to break chains
- `selectionController` reference dropped on next runloop turn after completion

**Window lifecycle:**
- `isReleasedWhenClosed = false` to let ARC manage window lifetime
- Controller strongly holds window during capture, releases on finish
- Async cleanup prevents re-entrancy issues during mouse tracking

### Permissions & Entitlements

**Required entitlements (TextOCR.entitlements):**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.screen-capture</key>
<true/>
```

**Info.plist privacy keys:**
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>This app needs screen recording permission to capture screenshots for text recognition.</string>

<key>LSUIElement</key>
<true/>  <!-- Menu bar app, no Dock icon -->
```

**Build configuration:**
- Must use at least ad-hoc code signing (`CODE_SIGN_IDENTITY="-"`)
- Do NOT use `CODE_SIGNING_REQUIRED=NO` as this prevents persistent permission grants
- Permissions reset on each launch if app is unsigned

### Global Hotkey System

Uses KeyboardShortcuts SPM package with custom name extension:
```swift
extension KeyboardShortcuts.Name {
    static let captureText = Self("captureText", default: .init(.two, modifiers: [.command, .shift]))
}
```

Register in AppDelegate:
```swift
KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
    self?.menuBarController?.handleCaptureText()
}
```

Settings window allows customization via `KeyboardShortcuts.RecorderCocoa`.

## Common Development Scenarios

### Adding a New Service

1. Create service file in `TextOCR/Services/`
2. Initialize in `CaptureCoordinator` as private property
3. Call from workflow in proper sequence
4. Add error handling with completion callbacks

### Modifying Capture Workflow

Edit `CaptureCoordinator.startCapture()` - this orchestrates the entire flow. Use timing instrumentation (CFAbsoluteTimeGetCurrent) to track performance.

### Debugging Cursor Issues

1. Check console logs for activation status: "Activation check - isActive: ..."
2. Look for "Entering fallback mode" vs "Normal mode" messages
3. Verify window level is `.screenSaver`
4. Check if `windowDidBecomeKey` is being called
5. Test from both normal apps and System Settings

### Debugging Memory Issues

Watch for:
- Retain cycles in closures (search for missing `[weak self]`)
- Windows not deallocating after close (check `isReleasedWhenClosed`)
- Callbacks not cleared in `windowWillClose`
- Timer/monitor cleanup in teardown

## Performance Targets

- End-to-end latency goal: <300ms (screenshot → clipboard)
- Use `CFAbsoluteTimeGetCurrent()` for timing measurements
- Console logs include timing for each workflow step

## Known Issues & Workarounds

See KNOWN_ISSUES.md for build warnings and platform-specific limitations.

**macOS Version Requirements:**
- ScreenCaptureKit requires macOS 12.3+
- Current deployment target should reflect this

**Cursor Reliability:**
- Dual-mode architecture ensures crosshair works even when app cannot become key
- Global event monitor requires no special permissions for mouse tracking
- System cursor hide/unhide must be balanced (cleanup in windowWillClose)

## Project Structure Notes

```
TextOCR/
├── App/
│   ├── AppDelegate.swift          # Lifecycle, hotkey setup
│   ├── MenuBarController.swift    # Menu bar UI, status item
│   └── KeyboardShortcutsExtension.swift  # Hotkey name definitions
├── Services/
│   ├── ScreenCaptureService.swift # Complex dual-mode capture logic
│   ├── OCRService.swift           # Vision Framework wrapper
│   └── ClipboardService.swift     # NSPasteboard wrapper
├── Coordinators/
│   └── CaptureCoordinator.swift   # Workflow orchestration
├── Views/
│   └── SettingsWindowController.swift  # Settings UI (SwiftUI + AppKit hybrid)
└── Helpers/
    └── LaunchAtLoginHelper.swift  # SMLoginItemSetEnabled wrapper
```

**SelectionWindow/SelectionView hierarchy:**
- Defined in ScreenCaptureService.swift (not separate files)
- SelectionWindow is the full-screen borderless overlay
- SelectionView handles drawing (selection rect, custom crosshair)
- SelectionWindowController manages lifecycle and delegates

## SwiftUI + AppKit Integration

Settings window uses SwiftUI hosted in NSWindow:
- `SettingsWindowController` wraps SwiftUI view in `NSHostingController`
- MenuBarController shows/hides settings window
- Settings persist to UserDefaults via `@AppStorage`
