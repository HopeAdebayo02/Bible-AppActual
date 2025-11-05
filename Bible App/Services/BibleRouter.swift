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
        lastCommand = .goToChapter(book: book, chapter: chapter)
        lastCommandId &+= 1
    }
    
    @MainActor
    func goToVerse(book: BibleBook, chapter: Int, verse: Int) {
        lastCommand = .goToVerse(book: book, chapter: chapter, verse: verse)
        lastCommandId &+= 1
    }
}


