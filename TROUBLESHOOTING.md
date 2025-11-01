# TextOCR Troubleshooting Guide

## Menu Bar Icon Not Appearing

### ✅ FIXED!

The issue was that Xcode was generating its own Info.plist instead of using our custom one with the required `LSUIElement` key.

**What was fixed:**
1. Changed `GENERATE_INFOPLIST_FILE = NO` in project.pbxproj
2. Added `INFOPLIST_FILE = TextOCR/App/Info.plist`
3. Added `INFOPLIST_KEY_LSUIElement = YES`
4. Added screen recording permission description

### How to Verify the Fix

1. **Rebuild the app:**
   ```bash
   xcodebuild -project TextOCR.xcodeproj -scheme TextOCR -configuration Debug clean build
   ```

2. **Launch the app:**
   ```bash
   open /Users/quang/Library/Developer/Xcode/DerivedData/TextOCR-bygqxjwlgqqyhjbcnbhpqcshdaof/Build/Products/Debug/TextOCR.app
   ```

   OR from Xcode: Press ⌘R

3. **Look for the menu bar icon:**
   - Check the top-right menu bar
   - Look for a document with viewfinder icon (📄🔍)
   - It should appear among other menu bar apps

4. **Verify Info.plist:**
   ```bash
   # Check that LSUIElement is set to true
   /usr/libexec/PlistBuddy -c "Print :LSUIElement" \
     /Users/quang/Library/Developer/Xcode/DerivedData/TextOCR-bygqxjwlgqqyhjbcnbhpqcshdaof/Build/Products/Debug/TextOCR.app/Contents/Info.plist
   ```

   Should output: `true`

### Common Issues

#### Issue: Still no menu bar icon after rebuild

**Solution:**
1. Quit any running instances of TextOCR:
   ```bash
   pkill -9 TextOCR
   ```

2. Clean the build folder:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/TextOCR-*
   ```

3. Rebuild:
   ```bash
   xcodebuild -project TextOCR.xcodeproj -scheme TextOCR clean build
   ```

4. Launch again from Xcode

#### Issue: App crashes on launch

**Check Console logs:**
```bash
log stream --predicate 'process == "TextOCR"' --level debug
```

Then launch the app and watch for errors.

#### Issue: Permission dialogs don't appear

**Grant permissions manually:**
1. Open **System Settings**
2. Go to **Privacy & Security** → **Privacy**
3. Select **Screen Recording**
4. Add TextOCR and enable the checkbox
5. Restart the app

### Testing the Menu Bar Icon

Once the icon appears:

1. **Click the icon** - you should see a dropdown menu
2. **Menu should contain:**
   - "Capture Text"
   - --------- (separator)
   - "Quit TextOCR"

3. **Test "Capture Text":**
   - Click "Capture Text"
   - Screen should dim with selection overlay
   - Click and drag to select an area
   - Press ESC to cancel (for testing)

### Verification Checklist

- [ ] App builds successfully
- [ ] Info.plist contains `LSUIElement = true`
- [ ] Info.plist contains `NSCameraUsageDescription`
- [ ] App runs without crashing
- [ ] Menu bar icon appears (📄 icon)
- [ ] Clicking icon shows menu
- [ ] Menu contains "Capture Text" and "Quit" items

### Debug Commands

```bash
# Check if app is running
ps aux | grep TextOCR | grep -v grep

# Check Info.plist
plutil -p /Users/quang/Library/Developer/Xcode/DerivedData/TextOCR-*/Build/Products/Debug/TextOCR.app/Contents/Info.plist | grep -A1 "LSUIElement\|NSCamera"

# Launch app with console output
/path/to/TextOCR.app/Contents/MacOS/TextOCR

# View all logs
log show --predicate 'eventMessage contains "TextOCR"' --last 1m
```

### Success Indicators

✅ Build succeeds
✅ `LSUIElement = true` in Info.plist
✅ App process running
✅ **Menu bar icon visible** (this is the key indicator!)
✅ Menu appears when icon clicked

---

**Last Updated**: 2025-10-31
**Status**: FIXED - Menu bar icon should now appear correctly
