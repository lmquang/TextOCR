//
//  ScreenCaptureService.swift
//  TextOCR
//
//  Service for capturing screen regions
//

import AppKit
import CoreGraphics
import ScreenCaptureKit

class ScreenCaptureService {

    private var selectionController: SelectionWindowController?
    private var isCapturing = false

    /// Initiates screen capture with region selection
    /// - Parameter completion: Callback with the captured image or nil if cancelled
    func captureRegion(completion: @escaping (NSImage?) -> Void) {
        // Guard against multiple simultaneous captures
        guard !isCapturing else {
            print("[ScreenCaptureService] Capture already in progress")
            completion(nil)
            return
        }
        isCapturing = true

        let startTime = CFAbsoluteTimeGetCurrent()

        // Create controller for selection window
        let controller = SelectionWindowController()
        selectionController = controller

        controller.onFinished = { [weak self] rect in
            guard let self = self else { return }

            if let rect = rect {
                // Capture the selected region asynchronously
                self.captureScreen(rect: rect) { image in
                    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                    if let image = image {
                        print("[ScreenCaptureService] Screen capture completed in \(String(format: "%.3f", timeElapsed))s")
                        completion(image)
                    } else {
                        print("[ScreenCaptureService] Failed to capture screen region")
                        completion(nil)
                    }
                }
            } else {
                print("[ScreenCaptureService] Selection cancelled")
                completion(nil)
            }

            // Drop the strong reference on next runloop turn to avoid re-entrancy
            DispatchQueue.main.async {
                self.selectionController = nil
                self.isCapturing = false
            }
        }

        controller.show()
    }

    /// Captures a specific rectangular region of the screen using ScreenCaptureKit
    /// - Parameter rect: The CGRect to capture (in global screen coordinates)
    /// - Parameter completion: Callback with captured image or nil if failed
    private func captureScreen(rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                // Get available screen content
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // Find the display that contains the selection rect
                guard let display = findDisplay(containing: rect, from: content.displays) else {
                    print("[ScreenCaptureService] No display found containing rect: \(rect)")
                    await MainActor.run {
                        completion(nil)
                    }
                    return
                }

                print("[ScreenCaptureService] Using display \(display.displayID) for capture")

                // Convert global screen coordinates to display-local coordinates
                let displayRect = CGRect(
                    x: CGFloat(display.frame.origin.x),
                    y: CGFloat(display.frame.origin.y),
                    width: CGFloat(display.width),
                    height: CGFloat(display.height)
                )

                let localRect = CGRect(
                    x: rect.origin.x - displayRect.origin.x,
                    y: rect.origin.y - displayRect.origin.y,
                    width: rect.width,
                    height: rect.height
                )

                print("[ScreenCaptureService] Display frame: \(displayRect), local rect: \(localRect)")

                // Create filter for the specific display
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // Configure capture with the display-local rect
                let config = SCStreamConfiguration()
                config.width = Int(rect.width)
                config.height = Int(rect.height)
                config.sourceRect = localRect

                // Capture the screenshot
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                let capturedImage = NSImage(cgImage: image, size: rect.size)
                print("[ScreenCaptureService] Captured image size: \(rect.width) x \(rect.height)")

                await MainActor.run {
                    completion(capturedImage)
                }

            } catch {
                print("[ScreenCaptureService] Failed to capture screen: \(error.localizedDescription)")
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }

    /// Finds the display that contains the given rect
    /// - Parameters:
    ///   - rect: The rect in global screen coordinates
    ///   - displays: Available displays from ScreenCaptureKit
    /// - Returns: The display containing the rect, or the first display if none found
    private func findDisplay(containing rect: CGRect, from displays: [SCDisplay]) -> SCDisplay? {
        // Calculate center point of selection
        let centerX = rect.origin.x + rect.width / 2
        let centerY = rect.origin.y + rect.height / 2

        print("[ScreenCaptureService] Looking for display containing point (\(centerX), \(centerY))")

        for display in displays {
            let displayRect = CGRect(
                x: CGFloat(display.frame.origin.x),
                y: CGFloat(display.frame.origin.y),
                width: CGFloat(display.width),
                height: CGFloat(display.height)
            )

            print("[ScreenCaptureService] Checking display \(display.displayID): \(displayRect)")

            if displayRect.contains(CGPoint(x: centerX, y: centerY)) {
                return display
            }
        }

        // Fallback to first display
        print("[ScreenCaptureService] No display contains the rect, using first display")
        return displays.first
    }

}

// MARK: - Selection Window Controller

final class SelectionWindowController: NSWindowController, NSWindowDelegate {

    var onFinished: ((CGRect?) -> Void)?
    private var resultRect: CGRect?
    private var cursorGuardTimer: DispatchSourceTimer?
    private var hasEstablishedCursor = false
    private var globalMonitor: Any?
    private var isInFallbackMode = false

    init() {
        let window = SelectionWindow()
        super.init(window: window)

        window.isReleasedWhenClosed = false  // Critical: Let ARC manage lifetime
        window.delegate = self
        window.controller = self  // Set controller reference

        // Wire up the selection view to controller
        if let selectionView = window.contentView as? SelectionView {
            selectionView.controller = self
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }

        // Freeze cursor rect updates during window activation
        window.disableCursorRects()

        // Try to activate app and make window key
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        window.makeKeyAndOrderFront(nil)

        // Wait to verify activation succeeded, otherwise use fallback mode
        startActivationWait(window)
    }

    private func startActivationWait(_ window: NSWindow) {
        let deadline = DispatchTime.now() + .milliseconds(200)
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self, weak window] in
            guard let self = self, let window = window else { return }

            let isActive = NSApp.isActive
            let isKey = window.isKeyWindow
            let isVisible = window.occlusionState.contains(.visible)
            let isOnActiveSpace = window.isOnActiveSpace

            print("[SelectionWindowController] Activation check - isActive: \(isActive), isKey: \(isKey), isVisible: \(isVisible), isOnActiveSpace: \(isOnActiveSpace)")

            if isActive && isKey && isVisible && isOnActiveSpace {
                // Normal mode: window is key, cursor rects will work
                self.primeCursor(for: window)
            } else {
                // Fallback mode: cannot become key (e.g., System Settings is frontmost)
                print("[SelectionWindowController] Entering fallback mode (app not active/key)")
                self.enterInactiveFallback(for: window)
            }
        }
    }

    /// Call this when user completes or cancels selection
    func finish(with rect: CGRect?) {
        guard resultRect == nil else {
            print("[SelectionWindowController] finish() called but resultRect already set, ignoring")
            return
        }
        resultRect = rect
        print("[SelectionWindowController] finish() called with rect: \(rect?.debugDescription ?? "nil")")

        // Do not close inline (could be within tracking). Defer to next runloop turn.
        // For borderless windows, we need to call close() directly, not performClose()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            print("[SelectionWindowController] Closing window...")
            window.close()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Wait until window is visible before enabling cursor rects
        if !window.occlusionState.contains(.visible) {
            DispatchQueue.main.async { [weak self, weak window] in
                if let window = window {
                    self?.primeCursor(for: window)
                }
            }
        } else {
            primeCursor(for: window)
        }
    }

    private func primeCursor(for window: NSWindow) {
        guard let view = window.contentView else { return }

        // Now let AppKit recompute cursor rects with our crosshair
        window.enableCursorRects()
        window.invalidateCursorRects(for: view)
        NSCursor.crosshair.set()

        // Guard against race condition on older macOS versions
        if !hasEstablishedCursor {
            startCursorGuard()
        }
    }

    private func startCursorGuard() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in
            guard let self = self, !self.hasEstablishedCursor else {
                self?.stopCursorGuard()
                return
            }
            NSCursor.crosshair.set()
        }
        cursorGuardTimer = timer
        timer.resume()
    }

    func stopCursorGuard() {
        cursorGuardTimer?.cancel()
        cursorGuardTimer = nil
    }

    func markCursorEstablished() {
        hasEstablishedCursor = true
        stopCursorGuard()
    }

    // MARK: - Fallback Mode (for System Settings, etc.)

    private func enterInactiveFallback(for window: NSWindow) {
        isInFallbackMode = true

        // Show window regardless of activation
        window.orderFrontRegardless()

        // Hide system cursor and draw our own
        NSCursor.hide()

        // Update crosshair to current mouse position
        if let selectionView = window.contentView as? SelectionView {
            selectionView.showCustomCrosshair = true
            let mouseLocation = NSEvent.mouseLocation
            let windowLocation = window.convertPoint(fromScreen: mouseLocation)
            selectionView.crosshairLocation = windowLocation
            selectionView.needsDisplay = true
        }

        // Start global mouse monitor to track cursor
        startGlobalMouseMonitors(window)
    }

    private func startGlobalMouseMonitors(_ window: NSWindow) {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged]) { [weak self, weak window] event in
            guard let self = self, let window = window else { return }

            // Update crosshair position
            let mouseLocation = NSEvent.mouseLocation
            let windowLocation = window.convertPoint(fromScreen: mouseLocation)

            if let selectionView = window.contentView as? SelectionView {
                selectionView.crosshairLocation = windowLocation
                selectionView.needsDisplay = true
            }

            // On first click, try to activate and switch to normal mode
            if event.type == .leftMouseDown {
                self.stopGlobalMonitor()
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                window.makeKeyAndOrderFront(nil)
                self.primeCursorWhenReady(window)
            }
        }
    }

    private func primeCursorWhenReady(_ window: NSWindow) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self, weak window] in
            guard let self = self, let window = window else { return }

            if NSApp.isActive && window.isKeyWindow && window.occlusionState.contains(.visible) {
                // Successfully activated, switch to normal mode
                print("[SelectionWindowController] Switched to normal mode from fallback")
                self.isInFallbackMode = false

                // Hide custom crosshair and unhide system cursor
                if let selectionView = window.contentView as? SelectionView {
                    selectionView.showCustomCrosshair = false
                    selectionView.needsDisplay = true
                }
                NSCursor.unhide()

                // Enable normal cursor rects
                self.primeCursor(for: window)
            } else {
                // Still not activated, try again
                self.primeCursorWhenReady(window)
            }
        }
    }

    private func stopGlobalMonitor() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    func windowWillClose(_ notification: Notification) {
        print("[SelectionWindowController] windowWillClose called")

        // Clean up fallback mode resources
        stopGlobalMonitor()
        if isInFallbackMode {
            NSCursor.unhide()
            isInFallbackMode = false
        }

        // Stop cursor guard timer
        stopCursorGuard()

        // Snapshot and clear callbacks to break chains deterministically
        let rect = resultRect
        resultRect = nil
        let completion = onFinished
        onFinished = nil

        print("[SelectionWindowController] Delivering result: \(rect?.debugDescription ?? "nil")")

        // Deliver result after we exit AppKit delegate stack
        DispatchQueue.main.async {
            completion?(rect)
        }
    }
}

// MARK: - Selection Window

class SelectionWindow: NSWindow {

    private var startPoint: NSPoint?
    private var currentRect: CGRect = .zero
    private let selectionView: SelectionView
    weak var controller: SelectionWindowController?

    // MARK: - Window Key Status

    /// Allow borderless window to become key window to receive keyboard events
    override var canBecomeKey: Bool {
        return true
    }

    /// Allow window to become main window
    override var canBecomeMain: Bool {
        return true
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        selectionView = SelectionView()
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }


    convenience init() {
        // Calculate the union of all screen frames to cover all displays
        let allScreensRect = Self.calculateAllScreensRect()

        guard allScreensRect.width > 0 && allScreensRect.height > 0 else {
            self.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        print("[SelectionWindow] Creating window spanning all screens: \(allScreensRect)")
        self.init(contentRect: allScreensRect, styleMask: .borderless, backing: .buffered, defer: false)

        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.hasShadow = false
        self.level = .screenSaver  // Above menu bar and Dock
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true

        self.contentView = selectionView
        selectionView.selectionWindow = self
    }

    /// Calculates a rect that spans all connected screens
    private static func calculateAllScreensRect() -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return .zero
        }

        // Calculate the union of all screen frames
        var unionRect = screens[0].frame
        for screen in screens.dropFirst() {
            unionRect = unionRect.union(screen.frame)
        }

        print("[SelectionWindow] Screen count: \(screens.count)")
        for (index, screen) in screens.enumerated() {
            print("[SelectionWindow] Screen \(index): \(screen.frame)")
        }
        print("[SelectionWindow] Union rect: \(unionRect)")

        return unionRect
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentRect = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }

        let currentPoint = event.locationInWindow
        let x = min(start.x, currentPoint.x)
        let y = min(start.y, currentPoint.y)
        let width = abs(currentPoint.x - start.x)
        let height = abs(currentPoint.y - start.y)

        currentRect = CGRect(x: x, y: y, width: width, height: height)
        selectionView.selectionRect = currentRect
        selectionView.needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        print("[SelectionWindow] mouseUp - currentRect: \(currentRect)")
        print("[SelectionWindow] controller is \(controller == nil ? "nil" : "set")")

        if currentRect.width > 10 && currentRect.height > 10 {
            // Convert window coordinates to screen coordinates
            let screenRect = convertRectToScreenCoordinates(currentRect)
            print("[SelectionWindow] Valid selection, calling finish with rect: \(screenRect)")
            controller?.finish(with: screenRect)
        } else {
            print("[SelectionWindow] Selection too small, calling finish with nil")
            controller?.finish(with: nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            controller?.finish(with: nil)
        }
    }

    private func convertRectToScreenCoordinates(_ rect: CGRect) -> CGRect {
        // The window spans all screens, so window coordinates are already in global screen coordinates
        // (with bottom-left origin like AppKit). We need to convert to top-left origin for ScreenCaptureKit.

        // Find the total height of the virtual screen space (all screens combined)
        let allScreensRect = Self.calculateAllScreensRect()

        // Convert from bottom-left origin to top-left origin
        // In AppKit: y=0 is at bottom, y increases upward
        // In ScreenCaptureKit/CoreGraphics: y=0 is at top, y increases downward
        let flippedY = allScreensRect.height - rect.origin.y - rect.height

        // The window origin is at allScreensRect.origin, so add that offset
        let globalRect = CGRect(
            x: rect.origin.x + allScreensRect.origin.x,
            y: flippedY + allScreensRect.origin.y,
            width: rect.width,
            height: rect.height
        )

        print("[SelectionWindow] Converting rect: \(rect) -> global: \(globalRect)")
        print("[SelectionWindow] allScreensRect: \(allScreensRect)")

        return globalRect
    }
}

// MARK: - Selection View

class SelectionView: NSView {

    var selectionRect: CGRect = .zero
    weak var selectionWindow: SelectionWindow?
    private var trackingArea: NSTrackingArea?
    weak var controller: SelectionWindowController?

    // Custom crosshair for fallback mode
    var showCustomCrosshair: Bool = false
    var crosshairLocation: NSPoint = .zero

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove all existing tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }

        // Create new tracking area that covers entire view
        // Use .activeAlways to work even when window isn't key
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .inVisibleRect,
            .mouseMoved,
            .cursorUpdate
        ]

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
        // Notify controller that cursor has been established
        controller?.markCursorEstablished()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        // Set crosshair cursor for the entire view
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw custom crosshair if in fallback mode
        if showCustomCrosshair {
            drawCustomCrosshair()
        }

        // Draw the selection rectangle
        if selectionRect.width > 0 && selectionRect.height > 0 {
            // Fill with semi-transparent white
            NSColor.white.withAlphaComponent(0.3).setFill()
            NSBezierPath(rect: selectionRect).fill()

            // Draw blue border
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: selectionRect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Draw dimensions label
            drawDimensionsLabel()
        }
    }

    private func drawCustomCrosshair() {
        let crosshairSize: CGFloat = 20
        let lineWidth: CGFloat = 2

        NSColor.white.setStroke()

        // Draw horizontal line
        let hLine = NSBezierPath()
        hLine.move(to: NSPoint(x: crosshairLocation.x - crosshairSize, y: crosshairLocation.y))
        hLine.line(to: NSPoint(x: crosshairLocation.x + crosshairSize, y: crosshairLocation.y))
        hLine.lineWidth = lineWidth
        hLine.stroke()

        // Draw vertical line
        let vLine = NSBezierPath()
        vLine.move(to: NSPoint(x: crosshairLocation.x, y: crosshairLocation.y - crosshairSize))
        vLine.line(to: NSPoint(x: crosshairLocation.x, y: crosshairLocation.y + crosshairSize))
        vLine.lineWidth = lineWidth
        vLine.stroke()

        // Draw center circle
        let circlePath = NSBezierPath(ovalIn: NSRect(
            x: crosshairLocation.x - 3,
            y: crosshairLocation.y - 3,
            width: 6,
            height: 6
        ))
        circlePath.lineWidth = lineWidth
        circlePath.stroke()
    }

    private func drawDimensionsLabel() {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let dimensionText = "\(width) × \(height)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]

        let attributedString = NSAttributedString(string: " \(dimensionText) ", attributes: attributes)
        let textSize = attributedString.size()

        // Position label above the selection box with a small gap
        let gap: CGFloat = 8
        let labelX = selectionRect.origin.x
        let labelY = selectionRect.origin.y + selectionRect.height + gap

        // Ensure label stays within bounds
        let maxY = bounds.height - textSize.height
        let finalY = min(labelY, maxY)

        let labelRect = CGRect(x: labelX, y: finalY, width: textSize.width, height: textSize.height)

        attributedString.draw(in: labelRect)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
}
