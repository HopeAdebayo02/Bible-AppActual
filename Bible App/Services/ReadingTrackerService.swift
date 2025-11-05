import Foundation
import Combine

final class ReadingTrackerService: ObservableObject {
    static let shared = ReadingTrackerService()

    @Published private(set) var readBookIds: Set<Int> = []

    private let storageKey = "readingTracker.readBookIds"

    private init() {
        load()
    }

    func isRead(bookId: Int) -> Bool {
        readBookIds.contains(bookId)
    }

    func toggle(bookId: Int) {
        if readBookIds.contains(bookId) {
            readBookIds.remove(bookId)
        } else {
            readBookIds.insert(bookId)
        }
        save()
    }

    func markAll(_ ids: [Int]) {
        readBookIds.formUnion(ids)
        save()
    }

    func clearAll() {
        readBookIds.removeAll()
        save()
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: storageKey), let list = try? JSONDecoder().decode([Int].self, from: data) {
            readBookIds = Set(list)
        }
    }

    private func save() {
        let d = UserDefaults.standard
        let list = Array(readBookIds)
        if let data = try? JSONEncoder().encode(list) {
            d.set(data, forKey: storageKey)
        }
        objectWillChange.send()
    }

    // MARK: - Reset
    func reset() {
        readBookIds = []
        load()
    }
}


