//
//  ClipboardService.swift
//  TextOCR
//
//  Service for managing clipboard operations
//

import AppKit

class ClipboardService {

    /// Copies the given text to the system clipboard
    /// - Parameter text: The text string to copy
    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("[ClipboardService] Copied text to clipboard: \(text.prefix(50))...")
    }
}
