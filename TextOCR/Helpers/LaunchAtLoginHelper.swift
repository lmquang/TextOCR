//
//  LaunchAtLoginHelper.swift
//  TextOCR
//
//  Helper for managing Launch at Login functionality
//

import Foundation
import ServiceManagement

class LaunchAtLoginHelper {

    static let shared = LaunchAtLoginHelper()

    private let launchAtLoginKey = "LaunchAtLogin"

    private init() {}

    /// Check if app is set to launch at login
    var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
            updateLaunchAtLogin(newValue)
        }
    }

    /// Update the system launch at login setting
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("[LaunchAtLoginHelper] Successfully registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("[LaunchAtLoginHelper] Successfully unregistered from launch at login")
                }
            } catch {
                print("[LaunchAtLoginHelper] Failed to update launch at login: \(error.localizedDescription)")
            }
        } else {
            // Legacy API for macOS 12 and earlier
            let success = SMLoginItemSetEnabled(
                "com.textocr.TextOCR" as CFString,
                enabled
            )
            if success {
                print("[LaunchAtLoginHelper] Successfully updated launch at login (legacy)")
            } else {
                print("[LaunchAtLoginHelper] Failed to update launch at login (legacy)")
            }
        }
    }

    /// Initialize launch at login state on app startup
    func initializeOnStartup() {
        // Sync with system state if possible
        if #available(macOS 13.0, *) {
            let systemStatus = SMAppService.mainApp.status
            let isRegistered = systemStatus == .enabled

            // Update UserDefaults to match system state
            if isRegistered != isEnabled {
                UserDefaults.standard.set(isRegistered, forKey: launchAtLoginKey)
                print("[LaunchAtLoginHelper] Synced with system state: \(isRegistered)")
            }
        }

        print("[LaunchAtLoginHelper] Launch at login is \(isEnabled ? "enabled" : "disabled")")
    }
}
