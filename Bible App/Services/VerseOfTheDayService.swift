import Foundation

struct VerseOfTheDay: Equatable {
    let text: String
    let reference: String
}

final class VerseOfTheDayService {
    static let shared = VerseOfTheDayService()

    private let cacheDateKey = "votd.date"
    private let cacheTextKey = "votd.text"
    private let cacheRefKey = "votd.ref"
    private let curatedFilename = "verses_of_the_day_curated"
    private let curatedExtension = "json"
    private let curatedAbsolutePath = "/Users/teknoflk/Desktop/Bible App/Bible App/verses_of_the_day_curated.json"
    private let curatedAnchorKey = "votd.curated.anchor"
    private let forceResetOnceKey = "votd.curated.forceResetOnce"
    private let resetVersionKey = "votd.reset.version"
    private let currentResetVersion = 2

    private var curatedVerses: [VerseOfTheDay]? = nil

    private init() {}

    func getToday() async -> VerseOfTheDay {
        let today = dateKey(Date())
        if let cached = loadFromCache(expectedDateKey: today) {
            return cached
        }

        // Prefer curated list if available
        if let fromCurated = await generateFromCuratedForToday() {
            saveToCache(dateKey: today, verse: fromCurated)
            return fromCurated
        }

        if let generated = await generateForToday() {
            saveToCache(dateKey: today, verse: generated)
            return generated
        }

        // Fallback if generation fails
        let fallback = VerseOfTheDay(text: "The LORD is my shepherd; I shall not want.", reference: "Psalm 23:1")
        saveToCache(dateKey: today, verse: fallback)
        return fallback
    }

    private func loadFromCache(expectedDateKey: String) -> VerseOfTheDay? {
        let d = UserDefaults.standard
        guard d.string(forKey: cacheDateKey) == expectedDateKey,
              let text = d.string(forKey: cacheTextKey),
              let ref = d.string(forKey: cacheRefKey),
              text.isEmpty == false, ref.isEmpty == false else {
            return nil
        }
        return VerseOfTheDay(text: text, reference: ref)
    }

    private func saveToCache(dateKey: String, verse: VerseOfTheDay) {
        let d = UserDefaults.standard
        d.set(dateKey, forKey: cacheDateKey)
        d.set(verse.text, forKey: cacheTextKey)
        d.set(verse.reference, forKey: cacheRefKey)
    }

    private func generateForToday() async -> VerseOfTheDay? {
        do {
            let books = try await BibleService.shared.fetchBooks()
            guard books.isEmpty == false else { return nil }

            // Create a deterministic seed from today's date; vary selections using different multipliers
            let cal = Calendar(identifier: .gregorian)
            let dayOfYear = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
            let year = cal.component(.year, from: Date())
            let seed = (dayOfYear * 977) ^ (year * 131)

            let bookIndex = abs(seed) % books.count
            let book = books[bookIndex]

            let chapter = (abs(seed * 37) % max(1, book.chapters)) + 1
            let verses = try await BibleService.shared.fetchVerses(bookId: book.id, chapter: chapter)
            let valid = verses.filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            guard valid.isEmpty == false else { return nil }

            let verseIndex = abs(seed * 101) % valid.count
            let v = valid[verseIndex]

            let text = v.text
            let reference = "\(book.name) \(v.chapter):\(v.verse)"
            return VerseOfTheDay(text: text, reference: reference)
        } catch {
            return nil
        }
    }

    // MARK: - Curated support
    private func loadCuratedVerses() -> [VerseOfTheDay] {
        if let cached = curatedVerses { return cached }

        // Try bundle first
        if let url = Bundle.main.url(forResource: curatedFilename, withExtension: curatedExtension),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([CuratedVerse].self, from: data) {
            let mapped = list.compactMap { $0.toModel() }
            curatedVerses = mapped
            return mapped
        }
        // Fallback to absolute path (useful during development)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: curatedAbsolutePath)),
           let list = try? JSONDecoder().decode([CuratedVerse].self, from: data) {
            let mapped = list.compactMap { $0.toModel() }
            curatedVerses = mapped
            return mapped
        }
        curatedVerses = []
        return []
    }

    private func generateFromCuratedForToday() async -> VerseOfTheDay? {
        let list = loadCuratedVerses()
        guard list.isEmpty == false else { return nil }

        // Anchor the rotation to a stored start date; reset once so "today" becomes Day 1
        let startKey = ensureCuratedAnchor()
        guard let startDate = parseDateKey(startKey) else { return list.first }

        let cal = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: Date())
        let startOfDay = cal.startOfDay(for: startDate)
        let days = cal.dateComponents([.day], from: startOfDay, to: todayStart).day ?? 0
        if days == 0, let j316 = findJohn316(in: list) { return j316 }
        let idx = ((days % list.count) + list.count) % list.count
        return list[idx]
    }

    private func ensureCuratedAnchor() -> String {
        let d = UserDefaults.standard
        let today = dateKey(Date())
        // Versioned one-time reset to today
        let storedVersion = d.object(forKey: resetVersionKey) as? Int ?? 0
        if storedVersion != currentResetVersion {
            d.set(today, forKey: curatedAnchorKey)
            d.set(currentResetVersion, forKey: resetVersionKey)
            clearCache()
            return today
        }
        // One-time reset: default true so after this update, we start Day 1 today
        let shouldForceReset = d.object(forKey: forceResetOnceKey) as? Bool ?? true
        if shouldForceReset {
            d.set(today, forKey: curatedAnchorKey)
            d.set(false, forKey: forceResetOnceKey)
            clearCache()
            return today
        }
        if let existing = d.string(forKey: curatedAnchorKey) {
            return existing
        }
        d.set(today, forKey: curatedAnchorKey)
        return today
    }

    private func parseDateKey(_ key: String) -> Date? {
        let comps = key.split(separator: "-")
        guard comps.count == 3,
              let y = Int(comps[0]),
              let m = Int(comps[1]),
              let d = Int(comps[2]) else { return nil }
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return cal.date(from: dc)
    }

    private func clearCache() {
        let d = UserDefaults.standard
        d.removeObject(forKey: cacheDateKey)
        d.removeObject(forKey: cacheTextKey)
        d.removeObject(forKey: cacheRefKey)
    }

    // Public: restart rotation so today is Day 1 and clear cached verse
    func restartAtToday() {
        let today = dateKey(Date())
        let d = UserDefaults.standard
        d.set(today, forKey: curatedAnchorKey)
        d.set(currentResetVersion, forKey: resetVersionKey)
        clearCache()
    }

    private func findJohn316(in list: [VerseOfTheDay]) -> VerseOfTheDay? {
        let targets = ["John 3:16", "Jn 3:16", "Jhn 3:16"]
        if let match = list.first(where: { v in
            let r = v.reference.trimmingCharacters(in: .whitespacesAndNewlines)
            return targets.contains(where: { r.localizedCaseInsensitiveContains($0) })
        }) { return match }
        return nil
    }

    private struct CuratedVerse: Decodable {
        let text: String
        let reference: String?
        let book: String?
        let chapter: Int?
        let verse: Int?
        let version: String?

        func toModel() -> VerseOfTheDay? {
            if let ref = reference, !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return VerseOfTheDay(text: text, reference: ref)
            }
            if let book, let chapter, let verse {
                return VerseOfTheDay(text: text, reference: "\(book) \(chapter):\(verse)")
            }
            return nil
        }
    }

    private func dateKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    // MARK: - Reset
    func reset() {
        clearCache()
        curatedVerses = nil
    }
}


