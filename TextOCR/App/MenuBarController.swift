//
//  MenuBarController.swift
//  TextOCR
//
//  Manages the menu bar icon and menu
//

import AppKit
import KeyboardShortcuts

class MenuBarController {

    private var statusItem: NSStatusItem?
    private let captureCoordinator = CaptureCoordinator()
    private var settingsWindowController: SettingsWindowController?

    func setupMenuBar() {
        NSLog("=== [MenuBarController] setupMenuBar() called ===")
        fputs("*** MenuBarController setupMenuBar started ***\n", stderr)

        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("=== [MenuBarController] statusItem created: \(String(describing: statusItem)) ===")

        // Set menu bar icon - use SF Symbol for professional, minimal look
        if let button = statusItem?.button {
            NSLog("=== [MenuBarController] button exists, setting icon ===")

            // Use text.viewfinder SF Symbol - minimal and descriptive
            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            if let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "TextOCR") {
                button.image = image.withSymbolConfiguration(config)
                button.image?.isTemplate = true  // Critical: enables auto light/dark mode adaptation
                NSLog("=== [MenuBarController] SF Symbol icon set ===")
                fputs("*** SF Symbol icon 'text.viewfinder' set ***\n", stderr)
            } else {
                // Fallback to simple viewfinder if text.viewfinder not available
                NSLog("=== [MenuBarController] text.viewfinder not found, trying viewfinder ===")
                if let fallbackImage = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "TextOCR") {
                    button.image = fallbackImage.withSymbolConfiguration(config)
                    button.image?.isTemplate = true
                    NSLog("=== [MenuBarController] Fallback icon 'viewfinder' set ===")
                }
            }
        } else {
            NSLog("=== [MenuBarController] ERROR: button is nil! ===")
            fputs("*** ERROR: statusItem.button is nil! ***\n", stderr)
        }

        // Create menu
        let menu = NSMenu()

        // Add "Capture Text" menu item with hotkey display
        let captureItem = NSMenuItem(
            title: "Capture Text",
            action: #selector(captureTextAction),
            keyEquivalent: ""
        )
        captureItem.target = self
        menu.addItem(captureItem)

        // Update menu item title to show current shortcut
        updateCaptureMenuItemTitle()

        // Add "Settings..." menu item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Add "Quit" menu item
        let quitItem = NSMenuItem(
            title: "Quit TextOCR",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Setup capture coordinator completion handler
        captureCoordinator.completionHandler = { [weak self] success, message in
            DispatchQueue.main.async {
                self?.handleCaptureCompletion(success: success, message: message)
            }
        }

        print("[MenuBarController] Menu bar setup complete")
    }

    @objc private func captureTextAction() {
        print("[MenuBarController] Capture Text clicked")
        captureCoordinator.startCapture()
    }

    /// Triggers text capture programmatically (e.g., from global hotkey)
    func triggerCapture() {
        print("[MenuBarController] Capture triggered programmatically")
        captureCoordinator.startCapture()
    }

    @objc private func openSettings() {
        print("[MenuBarController] Opening Settings window")

        // Create settings window if it doesn't exist
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        // Show and bring to front
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        print("[MenuBarController] Quitting application")
        NSApplication.shared.terminate(nil)
    }

    private func handleCaptureCompletion(success: Bool, message: String?) {
        if success {
            showNotification(title: "Text Copied", message: "Text has been copied to clipboard")
        } else {
            showNotification(title: "Capture Failed", message: message ?? "Unknown error")
        }
    }

    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
        print("[MenuBarController] Notification: \(title) - \(message)")
    }

    // MARK: - Menu Updates

    private func updateCaptureMenuItemTitle() {
        guard let menu = statusItem?.menu,
              let captureItem = menu.items.first else {
            return
        }

        // Get current shortcut and format it
        if let shortcut = KeyboardShortcuts.getShortcut(for: .captureText) {
            let shortcutString = formatShortcut(shortcut)
            captureItem.title = "Capture Text\t\t\(shortcutString)"
        } else {
            captureItem.title = "Capture Text"
        }
    }

    private func formatShortcut(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
        var result = ""

        // Add modifier symbols in standard macOS order
        if shortcut.modifiers.contains(.control) {
            result += "⌃"
        }
        if shortcut.modifiers.contains(.option) {
            result += "⌥"
        }
        if shortcut.modifiers.contains(.shift) {
            result += "⇧"
        }
        if shortcut.modifiers.contains(.command) {
            result += "⌘"
        }

        // Add the key - handle optional
        if let key = shortcut.key {
            result += getKeyString(for: key)
        } else {
            result += "?"
        }

        return result
    }

    private func getKeyString(for key: KeyboardShortcuts.Key) -> String {
        // Map common keys to their display strings
        switch key {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .space: return "Space"
        case .return: return "↩"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .tab: return "⇥"
        default: return "?"
        }
    }
}
