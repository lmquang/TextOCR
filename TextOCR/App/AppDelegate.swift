//
//  AppDelegate.swift
//  TextOCR
//
//  Application delegate for handling app lifecycle
//

import Cocoa
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("=== [AppDelegate] Application launched ===")
        print("[AppDelegate] Application launched")

        // Initialize launch at login state
        LaunchAtLoginHelper.shared.initializeOnStartup()

        // Initialize menu bar controller
        menuBarController = MenuBarController()
        NSLog("=== [AppDelegate] MenuBarController created ===")

        menuBarController?.setupMenuBar()
        NSLog("=== [AppDelegate] setupMenuBar called ===")

        // Setup global hotkeys
        setupGlobalHotkeys()

        print("[AppDelegate] TextOCR is ready")
        NSLog("=== [AppDelegate] TextOCR is ready ===")

        // Force print to stderr for debugging
        fputs("*** AppDelegate finished launching ***\n", stderr)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("[AppDelegate] Application terminating")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Global Hotkeys

    private func setupGlobalHotkeys() {
        // Register cmd+shift+2 hotkey for text capture
        KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
            print("[AppDelegate] Hotkey triggered (cmd+shift+2)")
            self?.menuBarController?.triggerCapture()
        }

        print("[AppDelegate] Global hotkey registered: cmd+shift+2")
    }
}
