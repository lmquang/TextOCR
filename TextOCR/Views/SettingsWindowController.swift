//
//  SettingsWindowController.swift
//  TextOCR
//
//  Settings window for configuring keyboard shortcuts
//

import AppKit
import KeyboardShortcuts

class SettingsWindowController: NSWindowController {

    private var shortcutRecorder: KeyboardShortcuts.RecorderCocoa?
    private var launchAtLoginCheckbox: NSButton?

    convenience init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()

        self.init(window: window)

        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        // Create main container
        let containerView = NSView(frame: window.contentView!.bounds)
        containerView.autoresizingMask = [.width, .height]

        // Create stack view for vertical layout
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)

        // Title label
        let titleLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        stackView.addArrangedSubview(titleLabel)

        // Create horizontal stack for shortcut recorder
        let shortcutRow = NSStackView()
        shortcutRow.orientation = .horizontal
        shortcutRow.alignment = .centerY
        shortcutRow.spacing = 12
        shortcutRow.translatesAutoresizingMaskIntoConstraints = false

        // Label for shortcut
        let shortcutLabel = NSTextField(labelWithString: "Capture Text:")
        shortcutLabel.alignment = .right
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shortcutLabel.widthAnchor.constraint(equalToConstant: 120)
        ])
        shortcutRow.addArrangedSubview(shortcutLabel)

        // Shortcut recorder
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .captureText)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recorder.widthAnchor.constraint(equalToConstant: 200)
        ])
        shortcutRow.addArrangedSubview(recorder)
        self.shortcutRecorder = recorder

        stackView.addArrangedSubview(shortcutRow)

        // Info text
        let infoLabel = NSTextField(labelWithString: "Click the recorder and press your desired keyboard shortcut.\nThe shortcut will be saved automatically.")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(infoLabel)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        stackView.addArrangedSubview(separator)

        // General Settings section
        let generalLabel = NSTextField(labelWithString: "General")
        generalLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        stackView.addArrangedSubview(generalLabel)

        // Launch at Login checkbox
        let launchCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(launchAtLoginChanged(_:)))
        launchCheckbox.state = LaunchAtLoginHelper.shared.isEnabled ? .on : .off
        launchCheckbox.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(launchCheckbox)
        self.launchAtLoginCheckbox = launchCheckbox

        // Add spacer to push content to top
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        ])
        stackView.addArrangedSubview(spacer)
        stackView.setHuggingPriority(.defaultLow, for: .vertical)

        containerView.addSubview(stackView)

        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        window.contentView = containerView

        print("[SettingsWindowController] Settings window UI created")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Prevent window from being released when closed
        window?.isReleasedWhenClosed = false

        print("[SettingsWindowController] Settings window loaded")
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let isEnabled = sender.state == .on
        LaunchAtLoginHelper.shared.isEnabled = isEnabled
        print("[SettingsWindowController] Launch at login changed to: \(isEnabled)")
    }
}
