//
//  CaptureCoordinator.swift
//  TextOCR
//
//  Coordinator that orchestrates the screenshot → OCR → clipboard workflow
//

import AppKit

class CaptureCoordinator {

    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let clipboardService = ClipboardService()

    var completionHandler: ((Bool, String?) -> Void)?

    /// Starts the capture workflow
    func startCapture() {
        let workflowStartTime = CFAbsoluteTimeGetCurrent()
        print("\n[CaptureCoordinator] ========== Starting Capture Workflow ==========")

        // Step 1: Capture screen region
        screenCaptureService.captureRegion { [weak self] image in
            guard let self = self else { return }
            guard let image = image else {
                print("[CaptureCoordinator] Capture cancelled or failed")
                self.completionHandler?(false, "Capture cancelled")
                return
            }

            print("[CaptureCoordinator] Screenshot captured, starting OCR...")

            // Step 2: Extract text using OCR
            let recognizedText = self.ocrService.extractText(from: image)

            if recognizedText.isEmpty {
                print("[CaptureCoordinator] No text recognized")
                self.completionHandler?(false, "No text found")
                return
            }

            print("[CaptureCoordinator] Text recognized, copying to clipboard...")

            // Step 3: Copy to clipboard
            self.clipboardService.copy(text: recognizedText)

            // Step 4: Show success notification
            NotificationWindow.showCopiedNotification()

            let totalTime = CFAbsoluteTimeGetCurrent() - workflowStartTime
            print("[CaptureCoordinator] ========== Workflow Complete ==========")
            print("[CaptureCoordinator] Total time: \(String(format: "%.3f", totalTime))s")
            print("[CaptureCoordinator] Text copied to clipboard (\(recognizedText.count) chars)")

            self.completionHandler?(true, recognizedText)
        }
    }
}

// MARK: - Notification Window

/// Displays a temporary notification message that fades out automatically
final class NotificationWindow: NSPanel {

    // Keep strong references to active notifications to prevent premature deallocation
    private static var activeNotifications: [NotificationWindow] = []
    private var hideWorkItem: DispatchWorkItem?

    private let messageLabel: NSTextField
    private let containerView: NSView

    init(message: String) {
        // Create container view with rounded corners
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))

        // Create message label
        messageLabel = NSTextField(labelWithString: message)
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2

        // Get screen dimensions for positioning
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

        let screenFrame = screen.visibleFrame
        let windowWidth: CGFloat = 240
        let windowHeight: CGFloat = 60

        // Position at top center of screen
        let windowX = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let windowY = screenFrame.origin.y + screenFrame.height - windowHeight - 20

        let windowRect = NSRect(
            x: windowX,
            y: windowY,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupViews()
    }

    private func setupWindow() {
        self.isReleasedWhenClosed = false  // Let ARC manage lifetime
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.ignoresMouseEvents = true
        self.hasShadow = true
    }

    private func setupViews() {
        // Setup container with gray transparent background and rounded corners
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.75).cgColor
        containerView.layer?.cornerRadius = 16

        // Add subtle shadow
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.25
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer?.shadowRadius = 12

        // Center label both horizontally and vertically
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])

        // Set container as content view
        self.contentView = containerView
    }

    /// Shows the notification with fade-in, displays for duration, then fades out
    /// - Parameter duration: How long to display before fading out (default: 2 seconds)
    func show(duration: TimeInterval = 2.0) {
        print("[NotificationWindow] Showing notification: \(messageLabel.stringValue)")

        // Add to active notifications to keep strong reference
        NotificationWindow.activeNotifications.append(self)

        // Start with transparent content view (not window alpha)
        contentView?.alphaValue = 0.0
        orderFrontRegardless()

        // Fade in content view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.contentView?.animator().alphaValue = 1.0
        })

        // Schedule fade out after duration
        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    /// Fades out and closes the notification window
    private func fadeOut() {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        guard let contentView = contentView else {
            cleanup()
            return
        }

        print("[NotificationWindow] Fading out notification")

        // Animate content view (not window) alpha
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            contentView.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            print("[NotificationWindow] Ordering out notification")

            // Order out, don't close during animation completion
            self.orderOut(nil)

            // Cleanup on next runloop turn to avoid animation teardown issues
            DispatchQueue.main.async {
                self.cleanup()
            }
        })
    }

    /// Cleanup and remove from active notifications
    private func cleanup() {
        print("[NotificationWindow] Cleaning up notification")
        NotificationWindow.activeNotifications.removeAll { $0 === self }
        // ARC will deallocate when last strong reference is removed
    }
}

// MARK: - Convenience Factory Methods

extension NotificationWindow {

    /// Shows a "Copied to clipboard" notification
    static func showCopiedNotification() {
        let notification = NotificationWindow(message: "✓ Copied to clipboard")
        notification.show(duration: 2.0)
    }

    /// Shows a custom message notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - duration: How long to display (default: 2 seconds)
    static func show(message: String, duration: TimeInterval = 2.0) {
        let notification = NotificationWindow(message: message)
        notification.show(duration: duration)
    }
}
