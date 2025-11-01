# TextOCR Feature Roadmap & Brainstorming

**Last Updated:** 2025-11-01
**Status:** Planning Phase

This document captures comprehensive feature ideas, priorities, and implementation strategies for TextOCR based on collaborative AI brainstorming sessions.

---

## Table of Contents

- [Vision & Positioning](#vision--positioning)
- [Current Pain Points](#current-pain-points)
- [Feature Tiers](#feature-tiers)
  - [Tier 1: High Impact Quick Wins](#tier-1-high-impact-quick-wins)
  - [Tier 2: Differentiation Features](#tier-2-differentiation-features)
  - [Tier 3: Power User Features](#tier-3-power-user-features)
  - [Tier 4: Premium Polish](#tier-4-premium-polish)
- [Implementation Phases](#implementation-phases)
- [Technical Architecture](#technical-architecture)
- [Competitive Differentiation](#competitive-differentiation)

---

## Vision & Positioning

> **"The developer-first OCR tool for macOS"**

### Core Principles
- **Privacy-first**: 100% offline processing, no cloud dependencies, no telemetry
- **Speed-first**: Optimize for sub-300ms latency with intelligent shortcuts (AX API fallback)
- **Developer-friendly**: CLI, automation, scriptable, code-aware features
- **Native polish**: True macOS integration with SwiftUI, AppKit, and system services
- **Open & extensible**: No vendor lock-in, support for automation and scripting

---

## Current Pain Points

Identified issues with the current implementation:

1. **No review step** - Text is auto-copied without user review/correction opportunity
2. **No history** - Previous captures are lost forever unless manually saved
3. **No language configuration** - Cannot specify OCR languages for better accuracy
4. **Limited post-processing** - No text cleanup/formatting options
5. **Minimal settings** - Limited customization and configuration
6. **No OCR confidence feedback** - Users can't tell when accuracy might be low
7. **Single-use captures** - Can't re-run OCR on the same region
8. **No integration** - Isolated tool with no Shortcuts/Services/automation support

---

## Feature Tiers

### Tier 1: High Impact Quick Wins

**Timeline:** 1-2 weeks
**Goal:** Address critical pain points with minimal effort

| Feature | User Value | Effort | Priority |
|---------|-----------|--------|----------|
| **Preview Pop-over with Edit** | Allows review and correction before copying; solves #1 pain point | Medium | P0 |
| **Confidence-Gated Auto-Copy** | If confidence > threshold: auto-copy; else: show preview for smart defaults | Low | P0 |
| **Basic Post-Processing Toggles** | Trim whitespace, remove line breaks, case conversion (UPPER/lower/Title) | Low | P0 |
| **Append to Clipboard Mode** | Hold modifier key to append instead of replace - great for multi-source gathering | Very Low | P1 |
| **Re-run Last Selection** | Cache last CGRect and add hotkey (⇧⌘3) to re-OCR without reselecting | Very Low | P0 |
| **Smart Data Detection** | Use NSDataDetector to make URLs/emails/dates/phones clickable in preview | Low | P1 |

#### Implementation Notes

**Preview Pop-over:**
```swift
// New component: PreviewCoordinator
// - Manages SwiftUI pop-over attached to menu bar icon
// - Shows TextField with detected text (editable)
// - Action buttons: Copy, Append, Close
// - Displays confidence score/warnings
```

**Confidence Gating:**
```swift
// In CaptureCoordinator after OCR:
let threshold = UserDefaults.standard.float(forKey: "autocopycondence_threshold") // default: 0.85
if averageConfidence >= threshold {
    clipboardService.copy(text)
    showBriefSuccessNotification()
} else {
    previewCoordinator.show(text: text, confidence: averageConfidence)
}
```

**Post-Processing:**
```swift
// New service: TextProcessor
enum TextTransform {
    case trim
    case unwrapLines
    case uppercased
    case lowercased
    case titleCased
    case codeBlock
}

func apply(_ transforms: [TextTransform], to text: String) -> String
```

---

### Tier 2: Differentiation Features

**Timeline:** 2-4 weeks
**Goal:** Stand out from CleanShot X, Snagit, and other OCR tools

| Feature | Differentiator | Developer Appeal | Effort |
|---------|----------------|------------------|--------|
| **AX-First, OCR-Fallback** | Try NSAccessibility API first; faster & more accurate for accessible apps | ⭐⭐⭐⭐⭐ | High |
| **Code Snippet Formatting** | Strip line numbers, preserve indentation, wrap in code fences, smart quote fixes | ⭐⭐⭐⭐⭐ | Medium |
| **Table/Markdown Export** | Detect columns via bounding boxes → export as Markdown table or CSV/TSV | ⭐⭐⭐⭐ | High |
| **CLI Interface** | `textocr capture`, `textocr image <path>` → outputs to stdout for scripting | ⭐⭐⭐⭐⭐ | Medium |
| **Custom Regex Pipeline** | User-defined regex replacements (strip prompts, fix quotes, remove artifacts) | ⭐⭐⭐⭐ | Medium |

#### Technical Deep-Dive

**AX-First Fallback:**
```swift
// New service: AccessibilityService.swift
class AccessibilityService {
    func extractText(from rect: CGRect) async throws -> AccessibleText? {
        // 1. Convert rect center to screen coordinates
        // 2. Use AXUIElementCopyElementAtPosition
        // 3. Query kAXSelectedText or kAXValue
        // 4. Return text + source metadata
        // 5. Return nil if permission denied or no text found
    }
}

// Integration in CaptureCoordinator:
if let axText = try? await axService.extractText(from: rect) {
    handleTextExtracted(axText.content, confidence: 1.0, method: .accessibility)
} else {
    // Fall back to Vision OCR (existing flow)
    ocrService.extractText(from: image) { ... }
}
```

**Benefits:**
- Instant results (no Vision processing delay)
- Perfect accuracy (actual text, not OCR interpretation)
- Works for terminals, IDEs, browsers with selection
- Privacy-preserving (reads what's already visible)

**Challenges:**
- Requires Accessibility permission (UX friction)
- Not all apps expose AX text
- Need clear fallback messaging

**Code Snippet Formatting:**
```swift
// Developer-specific transforms
enum CodeTransform {
    case stripLineNumbers           // Remove "1. ", "123: ", etc.
    case preserveIndentation         // Maintain leading whitespace structure
    case removePrompts               // Strip "$ ", "> ", ">>> ", etc.
    case wrapInFences(language: String?) // Add ```language ... ```
    case fixSmartQuotes              // Replace curly quotes with straight
    case removeTrailingWhitespace
}

// Example usage:
let codeText = processor.applyCodeTransforms([
    .stripLineNumbers,
    .removePrompts,
    .fixSmartQuotes,
    .wrapInFences(language: "swift")
], to: rawOCRText)
```

**CLI Interface Design:**
```bash
# Capture screen region (opens selection UI, blocks until complete)
textocr capture

# OCR from image file
textocr image /path/to/screenshot.png

# Options
textocr capture --language en,ja --format markdown
textocr image file.jpg --confidence-threshold 0.9 --output result.txt

# Piping examples
textocr capture | pbcopy
textocr image scan.png | grep "error" | wc -l
```

---

### Tier 3: Power User Features

**Timeline:** 4-8 weeks
**Goal:** Retention and advanced workflows

| Feature | User Value | Complexity | Priority |
|---------|-----------|------------|----------|
| **OCR History** | Retrieve previous captures without re-scanning | Medium | P1 |
| **Multi-Language Support** | Configure primary/secondary languages for Vision | Low | P1 |
| **QR/Barcode Detection** | Detect and parse QR codes, barcodes alongside text | Low | P2 |
| **Sticky Region/Window Mode** | Pin a region and continuously OCR (for logs, terminals, subtitles) | High | P2 |
| **Shortcuts Integration** | Expose "Get Text from Screen" action for automation | Medium | P1 |
| **macOS Quick Action** | Right-click image in Finder → "Extract Text with TextOCR" | Low | P1 |
| **Image Preprocessing** | Auto-contrast, binarization, deskew for low-quality sources | High | P2 |
| **Language Auto-Detection** | Use NLLanguageRecognizer to auto-select OCR languages | Medium | P2 |

#### Implementation Details

**OCR History:**
```swift
// Data model with SwiftData
@Model
class OCRHistoryItem {
    @Attribute(.unique) var id: UUID
    var text: String
    var timestamp: Date
    var confidence: Float
    var method: CaptureMethod // .ocr, .accessibility, .barcode
    var sourceRect: CGRect?
    var thumbnail: Data? // Optional small preview image

    // Privacy options
    var persistent: Bool // If false, clear on app quit
}

// Service
class HistoryService {
    private let maxInMemoryItems = 100
    private var ringBuffer: [OCRHistoryItem] = []

    func add(_ item: OCRHistoryItem, persistent: Bool)
    func recent(limit: Int) -> [OCRHistoryItem]
    func search(_ query: String) -> [OCRHistoryItem]
    func clear(beforeDate: Date)
}
```

**UI:**
- Menu bar popover shows recent 10 items
- Click item → copy to clipboard
- Search bar for filtering
- "Clear All" and "Private Mode" toggle

**Multi-Language Support:**
```swift
// Settings UI
struct LanguageSettingsView: View {
    @AppStorage("ocrLanguages") var languages: [String] = ["en-US"]
    @AppStorage("autoDetectLanguage") var autoDetect: Bool = false

    var body: some View {
        Form {
            Toggle("Auto-detect language", isOn: $autoDetect)

            if !autoDetect {
                LanguagePicker(selection: $languages)
            }
        }
    }
}

// In OCRService:
request.recognitionLanguages = languages // Pass to VNRecognizeTextRequest
```

**Sticky Region Mode:**
```swift
// Advanced feature: continuous monitoring
class StickyRegionCoordinator {
    var monitoredRegion: CGRect?
    var monitoredWindow: SCWindow?
    var pollInterval: TimeInterval = 2.0
    var onChange: (String) -> Void

    func startMonitoring(region: CGRect, mode: MonitorMode) {
        // .append: accumulate text
        // .replace: update single buffer
        // .pipe: send to file/process
    }
}
```

**Shortcuts Integration:**
```swift
// Create App Intents extension
struct CaptureTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Text from Screen"

    @Parameter(title: "Language")
    var language: String?

    @Parameter(title: "Format")
    var format: OutputFormat?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Trigger capture UI, wait for selection
        // Return recognized text
        return .result(value: text)
    }
}
```

---

### Tier 4: Premium Polish

**Timeline:** Long-term / Nice-to-have
**Goal:** Production-quality refinements

| Feature | Impact | Effort | Notes |
|---------|--------|--------|-------|
| **Handwriting Mode Toggle** | Better accuracy for handwritten text | Low | Expose Vision's recognition level |
| **PII Redaction Mode** | Auto-mask emails/phones/addresses | Medium | Privacy-focused feature |
| **Window Edge Snapping** | Selection snaps to window boundaries | Medium | Better precision |
| **Selection Magnifier** | Loupe for pixel-perfect selection | Medium | Polish |
| **Full VoiceOver Support** | Accessibility labels + announcements | High | Inclusivity |
| **First-Launch Onboarding** | Tooltip tutorial explaining hotkey | Low | Discoverability |
| **Visual/Audio Feedback** | Flash icon or play sound on completion | Low | Confirmation feedback |
| **Confidence Highlighting** | Underline low-confidence words in preview | Low | Visual QA guidance |
| **Custom Hotkey Profiles** | Multiple hotkeys for different workflows | Medium | Power user flexibility |

---

## Implementation Phases

### Phase 1: Foundation (Sprint 1-2)
**Goal:** Fix core UX pain points

**Features:**
- ✅ Preview pop-over with SwiftUI (MenuBarExtra for macOS 13+)
- ✅ Confidence gating (auto-copy vs preview based on threshold)
- ✅ 5 post-processing toggles (trim, unwrap lines, UPPER/lower/Title, code block)
- ✅ Append-to-clipboard mode (via modifier key)
- ✅ Re-run last selection hotkey (⇧⌘3)
- ✅ NSDataDetector for clickable URLs/emails in preview

**Architecture Changes:**
```
New Components:
- PreviewCoordinator.swift
- PreviewView.swift (SwiftUI)
- TextProcessor.swift

Modified Components:
- CaptureCoordinator: Add confidence routing logic
- OCRService: Return confidence scores with results
- ClipboardService: Add append mode
```

**Effort:** ~20-30 hours

---

### Phase 2: Developer Features (Sprint 3-4)
**Goal:** Stand out with dev-friendly capabilities

**Features:**
- ✅ AX-first OCR fallback (try Accessibility API first)
- ✅ Code snippet formatting (strip line numbers, preserve indentation)
- ✅ Table/CSV detection and Markdown export
- ✅ Basic in-memory history (ring buffer, 10 items)
- ✅ CLI interface (textocr-cli binary target)
- ✅ Custom regex pipeline settings

**Architecture Changes:**
```
New Components:
- AccessibilityService.swift
- CodeFormatter.swift
- TableDetector.swift
- HistoryService.swift (in-memory only)
- CLI/main.swift (new target)

Modified Components:
- CaptureCoordinator: Try AX before OCR
- Settings: Add regex rules UI
```

**Effort:** ~40-50 hours

---

### Phase 3: Ecosystem Integration (Sprint 5-6)
**Goal:** Integrate with macOS ecosystem

**Features:**
- ✅ Shortcuts app action (App Intents)
- ✅ Multi-language configuration in Settings
- ✅ QR/Barcode detection (VNDetectBarcodesRequest)
- ✅ Persistent history with SwiftData
- ✅ macOS Quick Action (NSService / Finder extension)
- ✅ Image preprocessing pipeline (Core Image)

**Architecture Changes:**
```
New Components:
- TextOCRIntents/ (App Intents extension)
- BarcodeService.swift
- ImagePreprocessor.swift
- HistoryView.swift (SwiftUI history browser)

Modified Components:
- HistoryService: Add SwiftData persistence
- OCRService: Add preprocessing step
- Settings: Language picker UI
```

**Effort:** ~50-60 hours

---

### Phase 4: Polish & Premium Features (Sprint 7+)
**Goal:** Production-quality refinements

**Features:**
- Window edge snapping
- Selection magnifier
- Full VoiceOver support
- First-launch onboarding
- Handwriting mode
- PII redaction
- Sticky region mode

**Effort:** ~60+ hours

---

## Technical Architecture

### Current Architecture
```
AppDelegate → MenuBarController → CaptureCoordinator → Services
                                         ↓
                     ScreenCaptureService / OCRService / ClipboardService
```

### Proposed Architecture (Phase 1-3)
```
AppDelegate
    ↓
MenuBarController (MenuBarExtra for macOS 13+)
    ├─ CaptureCoordinator
    │   ├─ AccessibilityService (try first)
    │   ├─ ScreenCaptureService (fallback)
    │   ├─ OCRService (Vision + confidence)
    │   ├─ BarcodeService (QR/barcode)
    │   └─ PreviewCoordinator (routing logic)
    │
    ├─ HistoryService (SwiftData)
    ├─ TextProcessor (transforms)
    ├─ ClipboardService (copy/append)
    └─ SettingsCoordinator
            ├─ GeneralSettings
            ├─ LanguageSettings
            ├─ HotKeySettings
            └─ RegexRulesSettings
```

### Service Layer Design

**AccessibilityService:**
```swift
class AccessibilityService {
    private var hasPermission: Bool { ... }

    func requestPermission() async -> Bool
    func extractText(from rect: CGRect) async throws -> AccessibleText?
    func extractText(from point: CGPoint) async throws -> AccessibleText?
}

struct AccessibleText {
    let content: String
    let source: AXUIElement
    let application: NSRunningApplication?
    let isEditable: Bool
}
```

**PreviewCoordinator:**
```swift
class PreviewCoordinator: ObservableObject {
    @Published var isVisible = false
    @Published var currentItem: PreviewItem?

    func show(text: String, confidence: Float, image: NSImage? = nil)
    func hide()
    func copyToClipboard(append: Bool = false)
    func applyTransforms(_ transforms: [TextTransform])
}

struct PreviewItem {
    var text: String
    let originalText: String
    let confidence: Float
    let detectedData: [DetectedDataItem] // URLs, emails, etc.
    let sourceImage: NSImage?
    let timestamp: Date
}
```

**TextProcessor:**
```swift
class TextProcessor {
    func apply(_ transforms: [TextTransform], to text: String) -> String

    func detectTables(_ text: String, boundingBoxes: [CGRect]) -> TableStructure?
    func formatAsMarkdownTable(_ table: TableStructure) -> String
    func formatAsCSV(_ table: TableStructure) -> String

    func applyRegexRules(_ rules: [RegexRule], to text: String) -> String
}

struct RegexRule: Codable {
    let name: String
    let pattern: String
    let replacement: String
    let enabled: Bool
}
```

---

## Competitive Differentiation

### vs. CleanShot X
**Their strengths:**
- Full screenshot suite (scrolling capture, video recording)
- Cloud sync and sharing
- Annotation tools

**Our advantages:**
- ✅ **Faster text extraction** (AX-first fallback)
- ✅ **Developer-focused** (CLI, code formatting, table export)
- ✅ **Privacy-first** (100% offline, no accounts)
- ✅ **Scriptable** (Shortcuts, AppleScript, CLI)
- ✅ **Open source potential** (no vendor lock-in)

### vs. Snagit
**Their strengths:**
- Cross-platform (Windows/Mac)
- Advanced editing suite
- Enterprise features

**Our advantages:**
- ✅ **macOS-native** (SwiftUI, system services, true native performance)
- ✅ **Lightweight** (menu bar app, no bloat)
- ✅ **Automation-friendly** (designed for workflows)
- ✅ **Free/open** (vs. $60+ license)

### vs. Built-in macOS Screenshot OCR
**Their strengths:**
- Zero installation
- System integration (⌘⇧4 then text selection)

**Our advantages:**
- ✅ **Editable preview** (system OCR auto-selects, no review)
- ✅ **History** (system has no recall)
- ✅ **Post-processing** (transformations, formatting)
- ✅ **Multi-language** (configurable vs. system default)
- ✅ **Automation** (CLI, Shortcuts)
- ✅ **Developer features** (code formatting, table export)

---

## Success Metrics

### Phase 1 Goals
- Reduce user-reported OCR errors by 50% (via preview + confidence gating)
- Average workflow time < 5 seconds (capture → reviewed copy)
- User satisfaction score > 4.5/5 for preview feature

### Phase 2 Goals
- 30% of captures use AX fallback (faster path)
- Developers report code snippet feature as "very useful" (survey)
- CLI adoption > 20% of active users

### Phase 3 Goals
- Average 5+ items in history per user session
- Shortcuts integration used by 15% of users
- Multi-language users report 80% satisfaction with accuracy

---

## Open Questions

1. **Monetization Strategy:**
   - Keep 100% free?
   - Freemium (basic free, pro features paid)?
   - Open source with optional donations?

2. **Accessibility Permission UX:**
   - How to request without feeling invasive?
   - Clear value proposition in permission dialog?
   - Fallback messaging when denied?

3. **History Privacy:**
   - Default to ephemeral (in-memory only)?
   - Require explicit opt-in for persistence?
   - Auto-expire after N days?

4. **Performance Targets:**
   - What's acceptable latency for preview pop-over?
   - Should we pre-warm Vision models on launch?
   - Memory budget for history (MB limit)?

5. **Distribution:**
   - Mac App Store (sandboxing challenges)?
   - Direct download / Homebrew?
   - Open source GitHub releases?

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Project architecture and development guide
- [README.md](../README.md) - User-facing documentation
- [KNOWN_ISSUES.md](../KNOWN_ISSUES.md) - Current limitations and bugs
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) - Common issues and solutions

---

## Contributing Ideas

Have a feature idea not listed here? Please:
1. Check if it aligns with "developer-first, privacy-first" principles
2. Consider implementation complexity vs. user value
3. Open a GitHub discussion or issue with:
   - Clear use case / user story
   - Expected behavior
   - Why existing features don't solve this

**Last updated:** 2025-11-01
**Next review:** After Phase 1 completion
