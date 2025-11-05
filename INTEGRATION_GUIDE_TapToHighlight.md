# Tap-to-Highlight Integration Guide

## Overview
This guide shows you how to integrate the tap-to-highlight functionality into your existing `VersesView.swift`.

## What You Get
- ✅ Single-tap any verse to toggle a blue highlight (same style as Verse of the Day)
- ✅ Multi-select mode still works for batch operations
- ✅ Highlights persist across app restarts via `HighlightService`
- ✅ Haptic feedback when highlighting/unhighlighting
- ✅ Visual consistency with your existing highlight system

## Step-by-Step Integration

### Step 1: Update the `onTapGesture` in `verseRow()`

**Find this code** (around line 97-101 in VersesView.swift):

```swift
.onTapGesture {
    if multiSelect.isEmpty == false {
        toggleSelect(verse.verse)
    }
}
```

**Replace it with**:

```swift
.onTapGesture {
    if multiSelect.isEmpty == false {
        // In multi-select mode: toggle selection for batch operations
        toggleSelect(verse.verse)
    } else {
        // In normal mode: toggle persistent highlight
        togglePersistentHighlight(
            verse: verse,
            book: currentBook,
            chapter: currentChapter,
            highlightService: highlightService
        )
    }
}
```

### Step 2: (Optional) Add Quick Highlight Button to Toolbar

If you want a button to highlight the currently selected verses in multi-select mode, add this to your toolbar:

**Find your toolbar section** (around line 300-400) and add:

```swift
if !multiSelect.isEmpty {
    Button {
        highlightSelectedVerses(
            selectedVerses: multiSelect,
            book: currentBook,
            chapter: currentChapter,
            highlightService: highlightService
        ) {
            multiSelect.removeAll()
        }
    } label: {
        Image(systemName: "highlighter")
            .font(.title3)
    }
}
```

### Step 3: Test the Feature

1. **Build and run** the app
2. **Tap any verse** → It should highlight with a blue overlay
3. **Tap again** → The highlight should remove
4. **Long-press and select multiple verses** → Existing multi-select still works
5. **Restart the app** → Your highlights should persist

## How It Works

### Single Tap (Normal Mode)
```
Tap verse → togglePersistentHighlight() → 
  Check if already highlighted →
    YES: Remove from HighlightService
    NO: Add to HighlightService with blue color
```

### Multi-Select Mode
```
Long press → Enter multi-select mode →
Tap verses → Add to selection (existing behavior) →
Tap highlight button → highlightSelectedVerses() → 
  Add range to HighlightService → Clear selection
```

## Customization Options

### Change Highlight Color

Edit `TapToHighlightHelper.swift`:

```swift
// Change this line:
let defaultTapHighlightColor = Color.blue.opacity(0.3)

// To your preferred color:
let defaultTapHighlightColor = Color.yellow.opacity(0.4)
// or
let defaultTapHighlightColor = Color.green.opacity(0.25)
```

### Add Color Picker

To let users choose their highlight color, you can:

1. Add a `@State` variable for the selected color in `VersesView`
2. Add a color picker in your toolbar/menu
3. Pass that color to `highlightService.addHighlight()` instead of using the default

Example:
```swift
@State private var selectedHighlightColor = Color.blue.opacity(0.3)

// In your menu:
ColorPicker("Highlight Color", selection: $selectedHighlightColor)

// When highlighting:
highlightService.addHighlight(
    bookId: bookId,
    chapter: chapter,
    startVerse: verseNumber,
    endVerse: verseNumber,
    color: selectedHighlightColor  // Use user's choice
)
```

## Troubleshooting

### Highlights don't appear
- Check that `InlineHighlightView` is working correctly
- Verify `highlightService.getHighlights()` returns data
- Check console for "TapToHighlight:" log messages

### Highlights don't persist
- Verify `HighlightService.shared` is properly saving to UserDefaults
- Check that the `@ObservedObject private var highlightService` line exists in VersesView

### Tap doesn't work
- Make sure you added the helper file to your Xcode project (not just the file system)
- Verify the `.onTapGesture` modification is in place
- Check that `togglePersistentHighlight()` is being called (add a print statement)

## Advanced: Color Palette

To add a quick color palette for common highlight colors:

```swift
extension VersesView {
    static let highlightColors: [Color] = [
        Color.blue.opacity(0.3),      // Default
        Color.yellow.opacity(0.4),    // Study notes
        Color.green.opacity(0.25),    // Key verses
        Color.orange.opacity(0.3),    // Action items
        Color.purple.opacity(0.25)    // Cross references
    ]
}
```

Then modify `togglePersistentHighlight()` to cycle through colors or show a picker.

## Need Help?

If you encounter any issues:
1. Check the console logs for "TapToHighlight:" messages
2. Verify the helper file is added to your Xcode target
3. Make sure `HighlightService.shared` is working properly
4. Test with a simple verse first before trying complex selections

## Summary

You now have:
- ✅ **`TapToHighlightHelper.swift`** - The core functionality
- ✅ **Single-tap highlighting** - Just change the onTapGesture
- ✅ **Persistent storage** - Automatic via HighlightService
- ✅ **Visual consistency** - Matches Verse of the Day style

The integration is minimal (one code change) and non-breaking to your existing functionality!
