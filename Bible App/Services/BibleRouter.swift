import Foundation
import SwiftUI

final class BibleRouter: ObservableObject {
    enum Command {
        case goToBooksRoot
        case goToChapter(book: BibleBook, chapter: Int)
        case goToVerse(book: BibleBook, chapter: Int, verse: Int)
    }

    @Published private(set) var lastCommandId: Int = 0
    private(set) var lastCommand: Command? = nil

    @MainActor
    func goToBooksRoot() {
        lastCommand = .goToBooksRoot
        lastCommandId &+= 1
    }

    @MainActor
    func goToChapter(book: BibleBook, chapter: Int) {
        print("🚀 BibleRouter.goToChapter: \(book.name) \(chapter)")
        lastCommand = .goToChapter(book: book, chapter: chapter)
        lastCommandId &+= 1
        print("📡 Command sent, ID: \(lastCommandId)")
    }
    
    @MainActor
    func goToVerse(book: BibleBook, chapter: Int, verse: Int) {
        print("🚀 BibleRouter.goToVerse: \(book.name) \(chapter):\(verse)")
        lastCommand = .goToVerse(book: book, chapter: chapter, verse: verse)
        lastCommandId &+= 1
        print("📡 Command sent, ID: \(lastCommandId)")
    }
    
    @MainActor
    func goToVerse(bookName: String, chapter: Int, verse: Int) {
        print("🚀 BibleRouter.goToVerse: Looking up '\(bookName)' \(chapter):\(verse)")
        Task {
            do {
                let books = try await BibleService.shared.fetchBooks()
                
                // Try exact match first
                if let book = books.first(where: { $0.name.lowercased() == bookName.lowercased() }) {
                    print("✅ Found exact match: \(book.name)")
                    goToVerse(book: book, chapter: chapter, verse: verse)
                    return
                }
                
                // Try partial match
                if let book = books.first(where: { 
                    $0.name.lowercased().contains(bookName.lowercased()) || 
                    bookName.lowercased().contains($0.name.lowercased())
                }) {
                    print("✅ Found partial match: \(book.name) for '\(bookName)'")
                    goToVerse(book: book, chapter: chapter, verse: verse)
                    return
                }
                
                print("❌ No matching book found for '\(bookName)'")
            } catch {
                print("❌ Error fetching books: \(error)")
            }
        }
    }
}


