import Foundation
import Combine
import SwiftUI

final class HighlightService: ObservableObject {
    static let shared = HighlightService()

    @Published private(set) var highlights: [VerseHighlight] = []

    private let highlightsKey = "highlight.verseHighlights"

    private init() {
        loadHighlights()
    }

    // Add or update a highlight for a verse range
    func setHighlight(bookId: Int, chapter: Int, startVerse: Int, endVerse: Int, colorHex: String) {
        // Remove any existing highlights that overlap with this range
        removeHighlight(bookId: bookId, chapter: chapter, startVerse: startVerse, endVerse: endVerse)

        // Add the new highlight
        let highlight = VerseHighlight(
            bookId: bookId,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
            colorHex: colorHex
        )
        highlights.append(highlight)
        saveHighlights()
    }

    // Remove highlight for a specific verse range
    func removeHighlight(bookId: Int, chapter: Int, startVerse: Int, endVerse: Int) {
        highlights.removeAll { highlight in
            highlight.bookId == bookId &&
            highlight.chapter == chapter &&
            highlight.startVerse <= endVerse &&
            highlight.endVerse >= startVerse
        }
        saveHighlights()
    }

    // Remove a specific highlight by ID
    func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
        saveHighlights()
    }

    // Get highlights for a specific chapter
    func highlightsForChapter(bookId: Int, chapter: Int) -> [VerseHighlight] {
        return highlights.filter { $0.bookId == bookId && $0.chapter == chapter }
    }
    
    // Alias for compatibility with TapToHighlightHelper
    func getHighlights(bookId: Int, chapter: Int) -> [VerseHighlight] {
        return highlightsForChapter(bookId: bookId, chapter: chapter)
    }
    
    // Add highlight method compatible with TapToHighlightHelper (accepts Color)
    func addHighlight(bookId: Int, chapter: Int, startVerse: Int, endVerse: Int, color: Color) {
        let colorHex = color.toHexString()
        setHighlight(bookId: bookId, chapter: chapter, startVerse: startVerse, endVerse: endVerse, colorHex: colorHex)
    }

    // Check if a verse is highlighted
    func isVerseHighlighted(bookId: Int, chapter: Int, verse: Int) -> Bool {
        return highlights.contains { highlight in
            highlight.bookId == bookId &&
            highlight.chapter == chapter &&
            verse >= highlight.startVerse &&
            verse <= highlight.endVerse
        }
    }

    // Get the highlight color for a verse (if highlighted)
    func colorForVerse(bookId: Int, chapter: Int, verse: Int) -> String? {
        return highlights.first { highlight in
            highlight.bookId == bookId &&
            highlight.chapter == chapter &&
            verse >= highlight.startVerse &&
            verse <= highlight.endVerse
        }?.colorHex
    }

    private func loadHighlights() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: highlightsKey), let list = try? JSONDecoder().decode([VerseHighlight].self, from: data) {
            highlights = list
        }
    }

    private func saveHighlights() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(highlights) {
            d.set(data, forKey: highlightsKey)
        }
        objectWillChange.send()
    }

    // MARK: - Reset
    func reset() {
        highlights = []
        loadHighlights()
    }
}

// MARK: - Color Extension
extension Color {
    func toHexString() -> String {
        // Convert SwiftUI Color to UIColor, then to hex string
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06x", rgb)
    }
}
