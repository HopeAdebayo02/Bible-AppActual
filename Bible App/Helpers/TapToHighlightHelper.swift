//
//  TapToHighlightHelper.swift
//  Bible App
//
//  Tap-to-highlight functionality for verses
//  Integrates with HighlightService for persistent highlighting
//

import SwiftUI

// MARK: - Tap-to-Highlight Helpers (Standalone Functions)

/// The default blue highlight color (matching Verse of the Day style)
let defaultTapHighlightColor = Color.blue.opacity(0.3)

/// Toggle persistent highlight for a single verse
/// - Parameters:
///   - verse: The verse to highlight/unhighlight
///   - book: The current book
///   - chapter: The current chapter
///   - highlightService: The highlight service instance
@MainActor
func togglePersistentHighlight(
    verse: BibleVerse,
    book: BibleBook,
    chapter: Int,
    highlightService: HighlightService
) {
    let bookId = book.id
    let verseNumber = verse.verse
    
    // Check if this verse is already highlighted
    let existingHighlights = highlightService.getHighlights(bookId: bookId, chapter: chapter)
    
    if let existing = existingHighlights.first(where: { highlight in
        verseNumber >= highlight.startVerse && verseNumber <= highlight.endVerse
    }) {
        // Remove existing highlight
        print("TapToHighlight: Removing highlight for \(book.name) \(chapter):\(verseNumber)")
        highlightService.removeHighlight(id: existing.id)
    } else {
        // Add new highlight
        print("TapToHighlight: Adding highlight for \(book.name) \(chapter):\(verseNumber)")
        highlightService.addHighlight(
            bookId: bookId,
            chapter: chapter,
            startVerse: verseNumber,
            endVerse: verseNumber,
            color: defaultTapHighlightColor
        )
    }
    
    // Provide haptic feedback
    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
}

/// Toggle persistent highlight for multiple selected verses
/// - Parameters:
///   - selectedVerses: Set of selected verse numbers
///   - book: The current book
///   - chapter: The current chapter
///   - highlightService: The highlight service instance
///   - onComplete: Callback to clear the selection
@MainActor
func highlightSelectedVerses(
    selectedVerses: Set<Int>,
    book: BibleBook,
    chapter: Int,
    highlightService: HighlightService,
    onComplete: @escaping () -> Void
) {
    guard !selectedVerses.isEmpty else { return }
    
    let bookId = book.id
    
    // Get the range of selected verses
    let sortedSelection = selectedVerses.sorted()
    guard let firstVerse = sortedSelection.first,
          let lastVerse = sortedSelection.last else { return }
    
    print("TapToHighlight: Adding multi-verse highlight for \(book.name) \(chapter):\(firstVerse)-\(lastVerse)")
    
    // Add highlight for the entire range
    highlightService.addHighlight(
        bookId: bookId,
        chapter: chapter,
        startVerse: firstVerse,
        endVerse: lastVerse,
        color: defaultTapHighlightColor
    )
    
    // Clear selection via callback
    onComplete()
    
    // Haptic feedback
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
}

/// Check if a verse is currently highlighted
/// - Parameters:
///   - verseNumber: The verse number to check
///   - book: The current book
///   - chapter: The current chapter
///   - highlightService: The highlight service instance
/// - Returns: True if the verse has a persistent highlight
@MainActor
func isVersePersistentlyHighlighted(
    _ verseNumber: Int,
    book: BibleBook,
    chapter: Int,
    highlightService: HighlightService
) -> Bool {
    let highlights = highlightService.getHighlights(bookId: book.id, chapter: chapter)
    return highlights.contains { highlight in
        verseNumber >= highlight.startVerse && verseNumber <= highlight.endVerse
    }
}
