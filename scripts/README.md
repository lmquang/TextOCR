# TextOCR Build Scripts

This directory contains scripts for building and configuring the TextOCR application.

## Scripts Overview

### 📦 build-app.sh

**Build and install the TextOCR app to /Applications**

```bash
./scripts/build-app.sh
```

**What it does:**
1. Cleans previous build artifacts
2. Builds TextOCR in Release configuration
3. Disables code signing for local development
4. Prompts to copy the app to `/Applications`
5. Removes existing version if present
6. Optionally cleans up build directory after installation

**When to use:**
- Building for production/release
- Installing to Applications folder for daily use
- Testing the final packaged app
- After major code changes

**Output location:** `build/Build/Products/Release/TextOCR.app`

---

### 🎨 setup-icon.sh

**Generate all app icon sizes from a source image**

```bash
./scripts/setup-icon.sh
```

**What it does:**
1. Reads source icon from `public/asset/icon.png` (1024x1024 recommended)
2. Generates all required macOS icon sizes using `sips`:
   - 16x16 (1x and 2x)
   - 32x32 (1x and 2x)
   - 128x128 (1x and 2x)
   - 256x256 (1x and 2x)
   - 512x512 (1x and 2x)
3. Updates `TextOCR/Assets.xcassets/AppIcon.appiconset/Contents.json`
4. All icons ready for Xcode to use

**When to use:**
- After creating/updating the app icon
- Setting up the project for the first time
- Changing branding/icon design

**Requirements:**
- Source icon at `public/asset/icon.png`
- Image should be 1024x1024 PNG with transparent or solid background
- macOS `sips` tool (built-in)

---

## Quick Start Guide

### First Time Setup

1. **Create your app icon:**
   ```bash
   # Create the directory
   mkdir -p public/asset

   # Add your 1024x1024 icon.png to public/asset/
   ```

2. **Generate icon sizes:**
   ```bash
   ./scripts/setup-icon.sh
   ```

3. **Build and install:**
   ```bash
   ./scripts/build-app.sh
   ```

### Development Workflow

**Option 1: Build via Script (Recommended for testing final builds)**
```bash
./scripts/build-app.sh
# Choose 'y' to install to Applications
# Choose 'n' to keep build artifacts for debugging
```

**Option 2: Xcode (Recommended for active development)**
```bash
open TextOCR.xcodeproj
# Use Xcode's build (⌘B) and run (⌘R) for faster iterations
```

---

## Build Configuration

### Release Build (Current Default)

```bash
CONFIGURATION="Release"
CODE_SIGN_IDENTITY="-"
CODE_SIGNING_REQUIRED=NO
```

- Optimized for performance
- No code signing (for local use)
- Smaller binary size
- Suitable for distribution to yourself

### Debug Build (For Development)

To build in Debug mode, edit `build-app.sh`:

```bash
CONFIGURATION="Debug"
```

Debug builds include:
- Debug symbols
- Faster compilation
- Better debugging in Xcode
- Larger binary size

---

## File Locations

### Source Files
- **Source icon:** `public/asset/icon.png`
- **Icon asset catalog:** `TextOCR/Assets.xcassets/AppIcon.appiconset/`

### Build Output
- **Build directory:** `build/`
- **Built app:** `build/Build/Products/Release/TextOCR.app`
- **Install location:** `/Applications/TextOCR.app`

### Generated Icons
All in `TextOCR/Assets.xcassets/AppIcon.appiconset/`:
- `icon_16x16.png`, `icon_16x16@2x.png`
- `icon_32x32.png`, `icon_32x32@2x.png`
- `icon_128x128.png`, `icon_128x128@2x.png`
- `icon_256x256.png`, `icon_256x256@2x.png`
- `icon_512x512.png`, `icon_512x512@2x.png`

---

## Troubleshooting

### Build Errors

**"xcodebuild: command not found"**
```bash
xcode-select --install
```

**"No scheme named TextOCR"**
- Open `TextOCR.xcodeproj` in Xcode
- Ensure the scheme is shared (Product → Scheme → Manage Schemes)

**Package dependency errors (KeyboardShortcuts)**
- Open project in Xcode
- File → Add Package Dependencies
- Add: `https://github.com/sindresorhus/KeyboardShortcuts`

### Icon Setup Errors

**"Source icon not found at public/asset/icon.png"**
```bash
# Create the directory
mkdir -p public/asset

# Add your 1024x1024 icon.png file there
```

**"sips command not found"**
- `sips` is built into macOS
- Make sure you're running on macOS

**Icon doesn't update in Xcode**
- Clean build folder (⌘⇧K in Xcode)
- Delete `DerivedData`: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Rebuild the project

### Installation Issues

**App already running**
- Quit TextOCR before running the build script
- Or the script will fail when trying to replace the app

**Permission denied copying to /Applications**
- The script should prompt for your password if needed
- If it fails, manually copy: `cp -R build/.../TextOCR.app /Applications/`

---

## Advanced Usage

### Custom Build Directory

Edit `build-app.sh`:
```bash
BUILD_DIR="/path/to/custom/build"
```

### Automatic Installation (No Prompts)

```bash
# Auto-answer yes to all prompts
yes | ./scripts/build-app.sh
```

### Keep Build Artifacts

When prompted "Do you want to clean up build artifacts?", answer `n` to:
- Debug build issues
- Inspect binary
- Check bundle contents
- Analyze build logs

### Extract Just the App

```bash
./scripts/build-app.sh
# Answer 'n' to "copy to Applications"
# The app will be at: build/Build/Products/Release/TextOCR.app
```

---

## Script Maintenance

### Updating Project Name

If you rename the project:

1. Edit `build-app.sh`:
   ```bash
   PROJECT_NAME="NewName"
   SCHEME_NAME="NewName"
   ```

2. Edit `setup-icon.sh`:
   ```bash
   APPICONSET="NewName/Assets.xcassets/AppIcon.appiconset"
   ```

---

## Integration with CI/CD

These scripts can be used in continuous integration:

```bash
#!/bin/bash
# CI build script
./scripts/setup-icon.sh
./scripts/build-app.sh <<< $'n\ny'  # Don't install, clean build dir
```

---

## Best Practices

### Development
- Use Xcode (⌘B/⌘R) for active coding
- Use `build-app.sh` to test final Release builds
- Keep build directory for debugging

### Icon Updates
- Always start with 1024x1024 source
- Run `setup-icon.sh` after any icon changes
- Clean build after icon updates

### Distribution
- Build with Release configuration
- Test the installed app from /Applications
- Verify all features work as expected

---

## File Permissions

Ensure scripts are executable:
```bash
chmod +x scripts/*.sh
```

---

## Support

For issues with:
- **Build script:** Check Xcode installation and project configuration
- **Icon script:** Verify source icon exists and is valid PNG
- **General issues:** See main project README.md and TROUBLESHOOTING.md
