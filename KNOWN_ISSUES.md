# Known Issues & Solutions

## ⚠️ Build Warning: Info.plist in Copy Bundle Resources

### Warning Message
```
The Copy Bundle Resources build phase contains this target's Info.plist file
'/Users/quang/workspace/lmquang/TextOCR/TextOCR/App/Info.plist'.
```

### Impact
**Non-critical** - The app builds and runs correctly. This is just a warning.

### Why This Happens
When Info.plist is added to the Xcode project navigator, Xcode automatically adds it to the target membership, which includes it in the "Copy Bundle Resources" build phase. However, Info.plist files should only be *referenced* via the `INFOPLIST_FILE` build setting, not copied as a resource.

### How to Fix (Optional)

**Option 1: Fix in Xcode (Recommended)**
1. Open `TextOCR.xcodeproj` in Xcode
2. Select `TextOCR/App/Info.plist` in the Project Navigator
3. Open the File Inspector (⌥⌘1 or View → Inspectors → File)
4. Under "Target Membership", **uncheck** the "TextOCR" checkbox
5. Rebuild the project

**Option 2: Manual Edit (Advanced)**
The Info.plist should not have a file reference in the PBXBuildFile section. Since our project correctly uses `INFOPLIST_FILE = TextOCR/App/Info.plist` in the build settings, the file will still be used properly even if not in the target membership.

### Verification
After fixing, rebuild and check:
```bash
xcodebuild -project TextOCR.xcodeproj -scheme TextOCR clean build 2>&1 | grep "Info.plist"
```

Should produce no warnings.

### Current Status
- ✅ App builds successfully
- ✅ Info.plist is correctly configured with LSUIElement
- ✅ Menu bar icon appears
- ⚠️ Warning present but doesn't affect functionality

---

## Future Considerations

### macOS 12.3+ Required for ScreenCaptureKit
The app uses `ScreenCaptureKit` for screen capture, which requires macOS 12.3 or later. For older macOS versions, we would need to:
- Use deprecated `CGWindowListCreateImage` API with `@available` checks
- Or set minimum deployment target to macOS 12.3

### NSUserNotification Deprecation
The app currently uses deprecated `NSUserNotification` API. Future versions should migrate to `UserNotifications` framework:
- Import `UserNotifications`
- Use `UNUserNotificationCenter`
- Request notification permissions

### Performance Target
Current target is <0.3 seconds end-to-end. After manual testing, if performance doesn't meet this target, consider:
- Optimizing OCR settings (accuracy vs speed)
- Async processing improvements
- Caching strategies

---

**Last Updated**: 2025-10-31
