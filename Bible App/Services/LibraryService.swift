import Foundation
import Combine

@MainActor
final class LibraryService: ObservableObject {
    static let shared = LibraryService()

    @Published private(set) var bookmarks: [Bookmark] = []
    @Published private(set) var notes: [UserNote] = []
    // Highlights removed
    @Published private(set) var crossReferences: [CrossReferenceLine] = []

    private let bookmarksKey = "library.bookmarks"
    private let notesKey = "library.notes"
    // private let highlightsKey = "library.highlights"
    private let crossRefsKey = "library.crossrefs"

    private var cancellable: AnyCancellable? = nil
    private init() {
        load()
        // Reload when auth state changes to swap namespaces
        cancellable = AuthService.shared.$isSignedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
    }

    func addBookmark(_ b: Bookmark) {
        bookmarks.insert(b, at: 0)
        save()
    }

    func deleteBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func addNote(_ n: UserNote) {
        notes.insert(n, at: 0)
        save()
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    // Highlights removed

    private func load() {
        let d = UserDefaults.standard
        let ns = currentNamespace()
        if let data = d.data(forKey: namespacedKey(bookmarksKey, ns)), let list = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = list
        }
        if let data = d.data(forKey: namespacedKey(notesKey, ns)), let list = try? JSONDecoder().decode([UserNote].self, from: data) {
            notes = list
        }
        // Highlights removed
        if let data = d.data(forKey: namespacedKey(crossRefsKey, ns)), let list = try? JSONDecoder().decode([CrossReferenceLine].self, from: data) {
            crossReferences = list
        }
    }

    private func save() {
        let d = UserDefaults.standard
        let ns = currentNamespace()
        if let data = try? JSONEncoder().encode(bookmarks) { d.set(data, forKey: namespacedKey(bookmarksKey, ns)) }
        if let data = try? JSONEncoder().encode(notes) { d.set(data, forKey: namespacedKey(notesKey, ns)) }
        // Highlights removed
        if let data = try? JSONEncoder().encode(crossReferences) { d.set(data, forKey: namespacedKey(crossRefsKey, ns)) }
        objectWillChange.send()
    }

    // MARK: - Namespacing per identity
    private func currentNamespace() -> String {
        if let uid = AuthService.shared.userId, uid.isEmpty == false { return "user:" + uid }
        // Persist a device id for guest namespace stability across launches
        let d = UserDefaults.standard
        if let existing = d.string(forKey: "device.uuid") { return "device:" + existing }
        let new = UUID().uuidString
        d.set(new, forKey: "device.uuid")
        return "device:" + new
    }

    private func namespacedKey(_ base: String, _ ns: String) -> String {
        return base + ":" + ns
    }

    // MARK: - Cross References
    func addCrossReference(_ line: CrossReferenceLine) {
        crossReferences.insert(line, at: 0)
        save()
    }

    func deleteCrossReference(id: UUID) {
        crossReferences.removeAll { $0.id == id }
        save()
    }

    func crossReferencesFor(sourceBookId: Int, chapter: Int, verse: Int) -> [CrossReferenceLine] {
        crossReferences
            .filter { $0.sourceBookId == sourceBookId && $0.sourceChapter == chapter && $0.sourceVerse == verse }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Reset
    func reset() {
        bookmarks = []
        notes = []
        crossReferences = []
        load()
    }
}
