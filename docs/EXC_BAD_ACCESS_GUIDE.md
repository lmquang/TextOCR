# EXC_BAD_ACCESS: Common Causes and Solutions in macOS/Swift

**Project**: TextOCR
**Date**: 2025-11-01
**Purpose**: Reference guide for diagnosing and fixing EXC_BAD_ACCESS crashes

---

## Table of Contents

1. [What is EXC_BAD_ACCESS?](#what-is-exc_bad_access)
2. [Common Causes in Our Codebase](#common-causes-in-our-codebase)
3. [Issue #1: Animating Window Alpha and Closing Inline](#issue-1-animating-window-alpha-and-closing-inline)
4. [Issue #2: Borderless Windows and performClose()](#issue-2-borderless-windows-and-performclose)
5. [Issue #3: isReleasedWhenClosed with ARC](#issue-3-isreleasedwhenclosed-with-arc)
6. [Diagnostic Process](#diagnostic-process)
7. [Prevention Patterns](#prevention-patterns)
8. [Quick Reference Checklist](#quick-reference-checklist)

---

## What is EXC_BAD_ACCESS?

**EXC_BAD_ACCESS** is a runtime error that occurs when your code attempts to access memory that:
- Has already been deallocated (use-after-free)
- Was never allocated
- Is protected/inaccessible

**Common manifestations:**
- `EXC_BAD_ACCESS (code=1, address=0x...)`
- Crashes in `NSApplicationMain` or AppKit internals
- Crashes that occur "later" after the problematic code executes
- Intermittent crashes that are hard to reproduce

**Why it's tricky in AppKit:**
- Crash may surface far from the actual bug location
- Animation completion handlers can trigger delayed crashes
- Window lifecycle is complex with multiple deallocation paths

---

## Common Causes in Our Codebase

We've encountered three major EXC_BAD_ACCESS patterns in this project:

1. **Animating window's own `alphaValue` then closing in completion** → Use-after-free during animation teardown
2. **Using `performClose()` on borderless windows** → Window never closes, stays in memory
3. **Setting `isReleasedWhenClosed = true` with ARC** → Double-free or premature deallocation

---

## Issue #1: Animating Window Alpha and Closing Inline

### The Problem

**Symptom**: Crash occurs AFTER notification window successfully displays and closes

**Code that crashes:**
```swift
class NotificationWindow: NSWindow {
    func show() {
        self.alphaValue = 0.0
        self.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0  // ❌ Animating window itself
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.fadeOut()
            }
        })
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            self.animator().alphaValue = 0.0  // ❌ Still animating window
        }, completionHandler: { [weak self] in
            self?.close()  // ❌ Closing while animation proxy is active
            NotificationWindow.activeNotifications.removeAll { $0 === self }
        })
    }
}
```

**Why it crashes:**

1. When you animate `self.animator().alphaValue`, AppKit creates an animation proxy for the **window object itself**
2. Core Animation sets up layer teardown handlers tied to the window
3. When `close()` is called in the completion handler, the window starts deallocating
4. But the animation proxy is still being torn down by Core Animation
5. The proxy tries to access the window → **EXC_BAD_ACCESS** (window is gone)

**The crash often shows up at `NSApplicationMain`** because the animation teardown happens asynchronously and the crash surfaces during the next event loop iteration.

### The Solution

**✅ Animate the contentView, not the window:**

```swift
final class NotificationWindow: NSPanel {
    private static var activeNotifications: [NotificationWindow] = []
    private var hideWorkItem: DispatchWorkItem?

    func show(duration: TimeInterval = 2.0) {
        NotificationWindow.activeNotifications.append(self)

        // ✅ Animate content view alpha, not window alpha
        contentView?.alphaValue = 0.0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.contentView?.animator().alphaValue = 1.0  // ✅ Content view
        })

        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func fadeOut() {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        guard let contentView = contentView else {
            cleanup()
            return
        }

        // ✅ Animate content view, not window
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            contentView.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }

            // ✅ Order out, don't close
            self.orderOut(nil)

            // ✅ Defer cleanup to next runloop turn
            DispatchQueue.main.async {
                self.cleanup()
            }
        })
    }

    private func cleanup() {
        NotificationWindow.activeNotifications.removeAll { $0 === self }
        // ARC deallocates when last reference removed
    }
}
```

**Key changes:**
1. ✅ Animate `contentView.animator().alphaValue` instead of `self.animator().alphaValue`
2. ✅ Use `orderOut(nil)` instead of `close()` in animation completion
3. ✅ Defer cleanup by one runloop cycle: `DispatchQueue.main.async`
4. ✅ Let ARC deallocate by removing from strong reference array

**Why this works:**
- Animating the content view means the window object is NOT being animated
- `orderOut()` hides the window without destroying it
- Deferring cleanup ensures all animation teardown completes before deallocation
- ARC safely deallocates once the strong reference is removed

**Files affected:**
- `CaptureCoordinator.swift` (NotificationWindow class)

**Session reference:**
- See `docs/sessions/202511011225-fix-app-hang-on-cancel/`

---

## Issue #2: Borderless Windows and performClose()

### The Problem

**Symptom**: Selection window doesn't close after capture, stays on screen forever

**Code that doesn't work:**
```swift
class SelectionWindow: NSWindow {
    convenience init() {
        self.init(
            contentRect: screenRect,
            styleMask: .borderless,  // ❌ Borderless window
            backing: .buffered,
            defer: false
        )
    }
}

class SelectionWindowController: NSWindowController {
    func finish(with rect: CGRect?) {
        DispatchQueue.main.async { [weak self] in
            self?.window?.performClose(nil)  // ❌ Doesn't work on borderless!
        }
    }
}
```

**Why it fails:**

1. `performClose(nil)` simulates clicking the window's close button
2. Borderless windows (`.borderless` styleMask) have **no close button**
3. `performClose()` does nothing when there's no button to simulate
4. Window never receives close event, stays visible forever

**Logs show:**
```
[SelectionWindow] mouseUp - calling finish
[SelectionWindowController] finish() called with rect: (...)
[SelectionWindowController] Closing window...
// ❌ No "windowWillClose" log - window never closes!
```

### The Solution

**✅ Use `close()` directly for borderless windows:**

```swift
class SelectionWindowController: NSWindowController {
    func finish(with rect: CGRect?) {
        guard resultRect == nil else { return }
        resultRect = rect

        // ✅ Use close() for borderless windows, not performClose()
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()  // ✅ Direct close
        }
    }
}
```

**Comparison:**

| Method | Works on Standard Windows | Works on Borderless Windows |
|--------|---------------------------|------------------------------|
| `performClose(nil)` | ✅ Yes | ❌ No |
| `close()` | ✅ Yes | ✅ Yes |
| `orderOut(nil)` | ✅ Yes (hides) | ✅ Yes (hides) |

**When to use each:**

- **Standard windows with controls**: Use `performClose()` - allows user to cancel via `windowShouldClose`
- **Borderless windows**: Use `close()` - direct close is required
- **Temporary windows**: Use `orderOut()` then defer `close()` or let ARC handle it

**Files affected:**
- `ScreenCaptureService.swift:150` (SelectionWindowController.finish)

**Session reference:**
- See `docs/sessions/202511011225-fix-app-hang-on-cancel/QUICK-REFERENCE.md`

---

## Issue #3: isReleasedWhenClosed with ARC

### The Problem

**Symptom**: Crashes, hangs, or unpredictable behavior with window lifecycle

**Code that causes issues:**
```swift
class NotificationWindow: NSWindow {
    func show() {
        window.isReleasedWhenClosed = true  // ❌ Pre-ARC API!
        window.orderFront(nil)
        // ... window gets deallocated unpredictably
    }
}
```

**Why it's wrong:**

1. `isReleasedWhenClosed = true` is a **pre-ARC** legacy API
2. With ARC, Swift automatically manages object lifetimes
3. Setting this to `true` tells AppKit to deallocate the window when closed
4. But ARC also manages deallocation based on strong references
5. **Result**: Conflict between AppKit and ARC → double-free or use-after-free

**What happens:**
- Window might deallocate while closures still reference it → crash
- Window might deallocate during animation → crash
- Window lifecycle becomes unpredictable and non-deterministic

### The Solution

**✅ Always set `isReleasedWhenClosed = false` with ARC:**

```swift
final class NotificationWindow: NSPanel {
    init() {
        super.init(...)

        // ✅ Let ARC manage lifetime
        self.isReleasedWhenClosed = false
    }
}
```

**Proper lifecycle pattern:**

```swift
final class NotificationWindow: NSPanel {
    private static var activeNotifications: [NotificationWindow] = []

    func show() {
        // ✅ Keep strong reference
        NotificationWindow.activeNotifications.append(self)
        self.orderFront(nil)
    }

    private func cleanup() {
        // ✅ Remove strong reference, let ARC deallocate
        NotificationWindow.activeNotifications.removeAll { $0 === self }
    }
}
```

**The correct pattern:**
1. ✅ Set `isReleasedWhenClosed = false`
2. ✅ Keep strong references to windows you want to keep alive
3. ✅ Remove strong references when done
4. ✅ Let ARC deallocate automatically

**Never do this:**
- ❌ `isReleasedWhenClosed = true` in modern Swift
- ❌ Relying on AppKit to manage window lifetime with ARC
- ❌ Using weak-only references for windows you need to stay alive

**Files affected:**
- `ScreenCaptureService.swift:122` (SelectionWindow)
- `CaptureCoordinator.swift:123` (NotificationWindow)

---

## Diagnostic Process

When you encounter `EXC_BAD_ACCESS`, follow this systematic approach:

### Step 1: Identify the Pattern

**Look for these symptoms:**

1. **Crash location**: Where does the crash show up?
   - `NSApplicationMain` → Likely animation teardown issue
   - Window close methods → Likely lifecycle issue
   - Random AppKit methods → Likely use-after-free

2. **Timing**: When does it crash?
   - During animation → Animating wrong object
   - After window closes → Deallocation timing issue
   - Intermittent → Race condition or ARC conflict

3. **Logs**: What was happening before crash?
   ```
   [NotificationWindow] Showing notification: ✓ Copied to clipboard
   [NotificationWindow] Fading out notification
   [NotificationWindow] Closing notification
   Thread 1: EXC_BAD_ACCESS  ← Crash after successful operation
   ```

### Step 2: Check Common Culprits

**Animation issues:**
```bash
# Search for window alpha animations
grep -r "self.animator().alphaValue" TextOCR/
grep -r "window?.animator()" TextOCR/
```

**Window closing issues:**
```bash
# Search for close calls
grep -r "performClose" TextOCR/
grep -r ".close()" TextOCR/
```

**Lifecycle issues:**
```bash
# Search for isReleasedWhenClosed
grep -r "isReleasedWhenClosed" TextOCR/
```

### Step 3: Apply Fixes

Follow the patterns documented in this guide:

1. **Animation crashes** → Use Issue #1 solution
2. **Window won't close** → Use Issue #2 solution
3. **Unpredictable crashes** → Use Issue #3 solution

### Step 4: Verify Fix

**Add logging to confirm:**
```swift
func fadeOut() {
    print("[Window] Starting fade out")

    NSAnimationContext.runAnimationGroup({ context in
        contentView.animator().alphaValue = 0.0
    }, completionHandler: {
        print("[Window] Animation complete")
        self.orderOut(nil)
        print("[Window] Ordered out")

        DispatchQueue.main.async {
            print("[Window] Cleanup starting")
            self.cleanup()
            print("[Window] Cleanup complete")
        }
    })
}
```

**Expected log sequence:**
```
[Window] Starting fade out
[Window] Animation complete
[Window] Ordered out
[Window] Cleanup starting
[Window] Cleanup complete
// No crash!
```

---

## Prevention Patterns

### Pattern 1: Temporary Window Lifecycle

**For notification/toast windows that show temporarily:**

```swift
final class TemporaryWindow: NSPanel {
    private static var activeWindows: [TemporaryWindow] = []

    convenience init(message: String) {
        self.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // ✅ Critical settings
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    func show(duration: TimeInterval) {
        // ✅ Keep strong reference
        TemporaryWindow.activeWindows.append(self)

        // ✅ Animate content view
        contentView?.alphaValue = 0.0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            self.contentView?.animator().alphaValue = 1.0
        })

        // ✅ Schedule cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.hide()
        }
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            self.contentView?.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)  // ✅ Order out, not close
            DispatchQueue.main.async {
                self?.cleanup()  // ✅ Deferred cleanup
            }
        })
    }

    private func cleanup() {
        TemporaryWindow.activeWindows.removeAll { $0 === self }
    }
}
```

### Pattern 2: Modal/Selection Window Lifecycle

**For selection windows managed by NSWindowController:**

```swift
final class SelectionController: NSWindowController, NSWindowDelegate {
    var onFinished: ((CGRect?) -> Void)?
    private var result: CGRect?

    init() {
        let window = SelectionWindow()
        super.init(window: window)

        // ✅ Critical settings
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.controller = self
    }

    func finish(with rect: CGRect?) {
        guard result == nil else { return }  // ✅ One-shot
        result = rect

        // ✅ For borderless: use close(), not performClose()
        DispatchQueue.main.async { [weak self] in
            self?.window?.close()
        }
    }

    func windowWillClose(_ notification: Notification) {
        let rect = result
        let completion = onFinished
        result = nil
        onFinished = nil

        // ✅ Deliver result after delegate stack
        DispatchQueue.main.async {
            completion?(rect)
        }
    }
}

class SelectionWindow: NSWindow {
    weak var controller: SelectionController?

    override var canBecomeKey: Bool { true }  // ✅ For borderless

    convenience init() {
        self.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func mouseUp(with event: NSEvent) {
        // ✅ Delegate to controller, never close inline
        controller?.finish(with: selectedRect)
    }
}
```

### Pattern 3: Strong Reference Management

**Keep windows alive during operations:**

```swift
class WindowManager {
    // ✅ Static storage for active windows
    private static var activeWindows: [NSWindow] = []

    static func show(_ window: NSWindow) {
        activeWindows.append(window)
        window.orderFront(nil)
    }

    static func hide(_ window: NSWindow) {
        window.orderOut(nil)

        // ✅ Remove on next runloop turn
        DispatchQueue.main.async {
            activeWindows.removeAll { $0 === window }
        }
    }
}
```

---

## Quick Reference Checklist

### ✅ Do's

- [x] **Animate contentView, not window**: `contentView?.animator().alphaValue`
- [x] **Use `close()` for borderless windows**: Not `performClose()`
- [x] **Set `isReleasedWhenClosed = false`**: Let ARC manage lifetime
- [x] **Use `orderOut()` before deallocation**: Don't close during animations
- [x] **Defer cleanup**: `DispatchQueue.main.async { cleanup() }`
- [x] **Keep strong references**: Use static arrays for temporary windows
- [x] **Use NSPanel for non-activating windows**: Not NSWindow
- [x] **Add `.nonactivatingPanel`**: Prevents focus stealing
- [x] **Override `canBecomeKey`**: For borderless windows needing keyboard events
- [x] **Use weak captures**: `[weak self]` in completion handlers
- [x] **One-shot patterns**: Guard against multiple calls

### ❌ Don'ts

- [ ] **Don't animate `self.animator().alphaValue`**: Animates window object
- [ ] **Don't call `close()` in animation completion**: Use `orderOut()` instead
- [ ] **Don't use `performClose()` on borderless**: Won't work
- [ ] **Don't set `isReleasedWhenClosed = true`**: Conflicts with ARC
- [ ] **Don't close windows inline during events**: Defer with `DispatchQueue.main.async`
- [ ] **Don't use weak-only references for windows**: Need strong owner
- [ ] **Don't forget to remove strong references**: Memory leak
- [ ] **Don't skip `wantsLayer = true`**: Required for content view animations
- [ ] **Don't forget delegate patterns**: Use `NSWindowDelegate` properly

---

## Example: Complete Safe Notification Window

Here's a complete, crash-free notification window implementation:

```swift
// File: CaptureCoordinator.swift

final class NotificationWindow: NSPanel {

    // Keep strong references to prevent premature deallocation
    private static var activeNotifications: [NotificationWindow] = []
    private var hideWorkItem: DispatchWorkItem?

    private let messageLabel: NSTextField
    private let containerView: NSView

    init(message: String) {
        // Setup container view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 60))
        containerView.wantsLayer = true  // ✅ Required for alpha animation

        // Setup label
        messageLabel = NSTextField(labelWithString: message)
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        messageLabel.textColor = .white
        messageLabel.alignment = .center

        // Position at top center of screen
        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        let screenFrame = screen.visibleFrame
        let windowRect = NSRect(
            x: screenFrame.midX - 120,
            y: screenFrame.maxY - 80,
            width: 240,
            height: 60
        )

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],  // ✅ Non-activating
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupViews()
    }

    private func setupWindow() {
        self.isReleasedWhenClosed = false  // ✅ Let ARC manage
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.ignoresMouseEvents = true
        self.hasShadow = true
    }

    private func setupViews() {
        // Style container
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.3
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        containerView.layer?.shadowRadius = 8

        // Add label
        messageLabel.frame = containerView.bounds.insetBy(dx: 16, dy: 0)
        messageLabel.autoresizingMask = [.width, .height]
        containerView.addSubview(messageLabel)

        self.contentView = containerView
    }

    func show(duration: TimeInterval = 2.0) {
        // ✅ Keep strong reference
        NotificationWindow.activeNotifications.append(self)

        // ✅ Animate content view, not window
        contentView?.alphaValue = 0.0
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.contentView?.animator().alphaValue = 1.0
        })

        // ✅ Schedule hide with cancellable work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func fadeOut() {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        guard let contentView = contentView else {
            cleanup()
            return
        }

        // ✅ Animate content view
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            contentView.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }

            // ✅ Order out, don't close
            self.orderOut(nil)

            // ✅ Defer cleanup to next runloop
            DispatchQueue.main.async {
                self.cleanup()
            }
        })
    }

    private func cleanup() {
        NotificationWindow.activeNotifications.removeAll { $0 === self }
        // ✅ ARC deallocates when last reference removed
    }
}

extension NotificationWindow {
    static func showCopiedNotification() {
        let notification = NotificationWindow(message: "✓ Copied to clipboard")
        notification.show(duration: 2.0)
    }
}
```

---

## Additional Resources

### Project Documentation
- **Session: Fix App Hang**: `docs/sessions/202511011225-fix-app-hang-on-cancel/`
- **GPT-5 Consultation**: `docs/sessions/202511011225-fix-app-hang-on-cancel/planning/gpt5-consultation.md`
- **Quick Reference**: `docs/sessions/202511011225-fix-app-hang-on-cancel/QUICK-REFERENCE.md`
- **Complete Solution**: `docs/sessions/202511011225-fix-app-hang-on-cancel/SOLUTION.md`

### Apple Documentation
- [NSWindow Class Reference](https://developer.apple.com/documentation/appkit/nswindow)
- [NSPanel Class Reference](https://developer.apple.com/documentation/appkit/nspanel)
- [NSWindowController](https://developer.apple.com/documentation/appkit/nswindowcontroller)
- [NSAnimationContext](https://developer.apple.com/documentation/appkit/nsanimationcontext)

### Key Takeaways
1. **Always animate views, not windows** - prevents animation proxy issues
2. **Use `orderOut()` before cleanup** - safer than `close()` during animations
3. **Defer cleanup by one runloop** - ensures animation teardown completes
4. **Set `isReleasedWhenClosed = false`** - let ARC manage lifetime
5. **Keep strong references during operations** - prevent premature deallocation
6. **Use `close()` for borderless windows** - `performClose()` doesn't work

---

**Last Updated**: 2025-11-01
**Status**: ✅ Active Reference Document
