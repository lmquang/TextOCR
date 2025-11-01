//
//  KeyboardShortcutsExtension.swift
//  TextOCR
//
//  Defines global keyboard shortcuts for the application
//

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey for triggering text capture
    /// Default: cmd+shift+2
    static let captureText = Self(
        "captureText",
        default: .init(.two, modifiers: [.command, .shift])
    )
}
