//
//  BibleService.swift
//  Bible App
//
//  Created by Hope Adebayo on 9/9/25.
//

import Foundation
import Supabase

class BibleService {
    static let shared = BibleService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // Fetch all Bible books
    func fetchBooks() async throws -> [BibleBook] {
        let response = try await client
            .from("books")
            .select()
            .order("id", ascending: true)
            .execute()

        let books = try JSONDecoder().decode([BibleBook].self, from: response.data)

        // Filter out any invalid entries (like "cancelled" or empty names)
        let validBooks = books.filter { book in
            !book.name.isEmpty &&
            book.name != "cancelled" &&
            book.id > 0 &&
            book.chapters > 0
        }

        return validBooks
    }

    // Fetch number of chapters for a given book id
    func chapterCount(for bookId: Int) async throws -> Int {
        let response = try await client
            .from("books")
            .select("chapters")
            .eq("id", value: bookId)
            .single()
            .execute()
        struct Row: Codable { let chapters: Int }
        let row = try JSONDecoder().decode(Row.self, from: response.data)
        return row.chapters
    }

    // Get book name by ID
    func getBookName(byId bookId: Int) -> String? {
        // This is a simple synchronous lookup - in a real app you might cache this
        // For now, we'll use a basic mapping. You could enhance this by storing books locally
        let bookNames: [Int: String] = [
            1: "Genesis", 2: "Exodus", 3: "Leviticus", 4: "Numbers", 5: "Deuteronomy",
            6: "Joshua", 7: "Judges", 8: "Ruth", 9: "1 Samuel", 10: "2 Samuel",
            11: "1 Kings", 12: "2 Kings", 13: "1 Chronicles", 14: "2 Chronicles",
            15: "Ezra", 16: "Nehemiah", 17: "Esther", 18: "Job", 19: "Psalms",
            20: "Proverbs", 21: "Ecclesiastes", 22: "Song of Solomon", 23: "Isaiah",
            24: "Jeremiah", 25: "Lamentations", 26: "Ezekiel", 27: "Daniel",
            28: "Hosea", 29: "Joel", 30: "Amos", 31: "Obadiah", 32: "Jonah",
            33: "Micah", 34: "Nahum", 35: "Habakkuk", 36: "Zephaniah",
            37: "Haggai", 38: "Zechariah", 39: "Malachi", 40: "Matthew",
            41: "Mark", 42: "Luke", 43: "John", 44: "Acts", 45: "Romans",
            46: "1 Corinthians", 47: "2 Corinthians", 48: "Galatians", 49: "Ephesians",
            50: "Philippians", 51: "Colossians", 52: "1 Thessalonians", 53: "2 Thessalonians",
            54: "1 Timothy", 55: "2 Timothy", 56: "Titus", 57: "Philemon",
            58: "Hebrews", 59: "James", 60: "1 Peter", 61: "2 Peter", 62: "1 John",
            63: "2 John", 64: "3 John", 65: "Jude", 66: "Revelation"
        ]
        return bookNames[bookId]
    }

    // Map a canonical book name (with common aliases) to its canonical ID (1-66)
    func canonicalBookId(for name: String) -> Int? {
        // Normalize: lowercase, trim, collapse inner whitespace, strip extra punctuation marks we do not care about
        let lowered = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = lowered.replacingOccurrences(of: "[’'`]+", with: "'", options: .regularExpression)
        let collapsed = stripped.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Common aliases and numeric variants
        let map: [String: Int] = [
            // Pentateuch
            "genesis": 1, "exodus": 2, "leviticus": 3, "numbers": 4, "deuteronomy": 5,
            // History
            "joshua": 6, "judges": 7, "ruth": 8,
            "1 samuel": 9, "i samuel": 9, "first samuel": 9,
            "2 samuel": 10, "ii samuel": 10, "second samuel": 10,
            "1 kings": 11, "i kings": 11, "first kings": 11,
            "2 kings": 12, "ii kings": 12, "second kings": 12,
            "1 chronicles": 13, "i chronicles": 13, "first chronicles": 13,
            "2 chronicles": 14, "ii chronicles": 14, "second chronicles": 14,
            "ezra": 15, "nehemiah": 16, "esther": 17,
            // Wisdom
            "job": 18, "psalms": 19, "psalm": 19, "proverbs": 20,
            "ecclesiastes": 21,
            // Song of Solomon aliases
            "song of solomon": 22, "song of songs": 22, "canticles": 22, "song": 22,
            // Prophets
            "isaiah": 23, "jeremiah": 24, "lamentations": 25, "ezekiel": 26, "daniel": 27,
            "hosea": 28, "joel": 29, "amos": 30, "obadiah": 31, "jonah": 32,
            "micah": 33, "nahum": 34, "habakkuk": 35, "zephaniah": 36, "haggai": 37,
            "zechariah": 38, "malachi": 39,
            // Gospels + Acts
            "matthew": 40, "mark": 41, "luke": 42, "john": 43, "acts": 44,
            // Pauline epistles
            "romans": 45,
            "1 corinthians": 46, "i corinthians": 46, "first corinthians": 46,
            "2 corinthians": 47, "ii corinthians": 47, "second corinthians": 47,
            "galatians": 48, "ephesians": 49, "philippians": 50, "colossians": 51,
            "1 thessalonians": 52, "i thessalonians": 52, "first thessalonians": 52,
            "2 thessalonians": 53, "ii thessalonians": 53, "second thessalonians": 53,
            "1 timothy": 54, "i timothy": 54, "first timothy": 54,
            "2 timothy": 55, "ii timothy": 55, "second timothy": 55,
            "titus": 56, "philemon": 57,
            // General epistles + Revelation
            "hebrews": 58, "james": 59,
            "1 peter": 60, "i peter": 60, "first peter": 60,
            "2 peter": 61, "ii peter": 61, "second peter": 61,
            "1 john": 62, "i john": 62, "first john": 62,
            "2 john": 63, "ii john": 63, "second john": 63,
            "3 john": 64, "iii john": 64, "third john": 64,
            "jude": 65, "revelation": 66, "revelation of john": 66, "apocalypse": 66
        ]
        if let id = map[collapsed] { return id }
        return nil
    }

    // Canonical order index (0-based) for sorting; unknown names sort last
    func canonicalOrderIndex(for name: String) -> Int {
        guard let id = canonicalBookId(for: name) else { return 10_000 }
        return id - 1
    }

    // Fetch verses from a specific book and chapter, filtered by selected translation
    func fetchVerses(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        let response = try await client
            .from("verses")
            .select()
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("version", value: TranslationService.shared.version)
            .order("verse", ascending: true)
            .execute()

        var verses = try JSONDecoder().decode([BibleVerse].self, from: response.data)
        // Light sanitation to remove artifacts in verse and heading, and drop blank rows
        verses = verses.map { v in
            let cleanedText = BibleService.sanitize(text: v.text)
            let cleanedHeading = v.heading.map { BibleService.sanitize(text: $0) }
            var out = BibleVerse(id: v.id, book_id: v.book_id, chapter: v.chapter, verse: v.verse, text: cleanedText, version: v.version, heading: cleanedHeading)
            // Heuristic: Some BSB rows embed the heading at the start of verse 1 text.
            if (out.version.uppercased().contains("BSB")) && out.verse == 1 && (out.heading == nil || out.heading?.isEmpty == true) {
                let split = BibleService.extractInlineHeading(from: out.text)
                if let h = split.heading, !h.isEmpty {
                    out = BibleVerse(id: out.id, book_id: out.book_id, chapter: out.chapter, verse: out.verse, text: split.body, version: out.version, heading: h)
                }
            }
            return out
        }
        // Do not drop blank-text rows; some datasets include placeholders/line breaks that preserve numbering.
        // Keeping them avoids gaps and empty-chapter issues downstream.
        // Resolve duplicates: if subsequent verse numbers are missing, split duplicates into
        // sequential verses; otherwise merge true duplicates by concatenating distinct texts.
        verses = BibleService.resolveDuplicateVerses(verses)
        // Sort by verse then id to keep stable order
        verses.sort { (a, b) in
            if a.verse == b.verse { return a.id < b.id }
            return a.verse < b.verse
        }
        // Normalize numbering by filling any missing verse numbers with placeholders
        verses = BibleService.normalizeContiguousNumbering(
            verses: verses,
            bookId: bookId,
            chapter: chapter
        )
        if verses.isEmpty {
            let sel = TranslationService.shared.version.uppercased()
            print("📖 Supabase returned empty verses for \(sel). Attempting API fallback...")
            if sel == "ESV" {
                print("🔑 Attempting ESV API...")
                if let esv = try? await fetchVersesFromESV(bookId: bookId, chapter: chapter), esv.isEmpty == false {
                    print("✅ ESV API succeeded")
                    return esv
                } else {
                    print("❌ ESV API failed")
                    throw NSError(domain: "BibleService", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load ESV verses. The ESV API is currently unavailable or returned no content for this passage."
                    ])
                }
            } else if sel == "NLT" {
                print("🔑 Attempting NLT API...")
                if let nlt = try? await fetchVersesFromNLT(bookId: bookId, chapter: chapter), nlt.isEmpty == false {
                    print("✅ NLT API succeeded")
                    return nlt
                } else {
                    print("❌ NLT API failed")
                    throw NSError(domain: "BibleService", code: 1001, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load NLT verses. The NLT API is currently unavailable or returned no content for this passage."
                    ])
                }
            } else if sel == "KJV" {
                print("🔑 Attempting KJV API...")
                if let kjv = try? await fetchVersesFromPublicAPI(bookId: bookId, chapter: chapter, translation: "kjv"), kjv.isEmpty == false {
                    print("✅ KJV API succeeded")
                    return kjv
                } else {
                    print("❌ KJV API failed")
                    throw NSError(domain: "BibleService", code: 1003, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load KJV verses. The KJV API is currently unavailable or returned no content for this passage."
                    ])
                }
            }
            if let fallback = try? await fetchVersesFromPublicAPI(bookId: bookId, chapter: chapter), fallback.isEmpty == false {
                print("✅ WEB fallback succeeded")
                return fallback
            }
        }
        return verses
    }

    // Version-aware overload to validate arbitrary translations without mutating global state
    func fetchVerses(bookId: Int, chapter: Int, version: String) async throws -> [BibleVerse] {
        let response = try await client
            .from("verses")
            .select()
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("version", value: version)
            .order("verse", ascending: true)
            .execute()

        var verses = try JSONDecoder().decode([BibleVerse].self, from: response.data)
        verses = verses.map { v in
            let cleanedText = BibleService.sanitize(text: v.text)
            let cleanedHeading = v.heading.map { BibleService.sanitize(text: $0) }
            return BibleVerse(id: v.id, book_id: v.book_id, chapter: v.chapter, verse: v.verse, text: cleanedText, version: v.version, heading: cleanedHeading)
        }
        verses = BibleService.resolveDuplicateVerses(verses)
        verses.sort { (a, b) in
            if a.verse == b.verse { return a.id < b.id }
            return a.verse < b.verse
        }
        verses = BibleService.normalizeContiguousNumbering(
            verses: verses,
            bookId: bookId,
            chapter: chapter
        )
        if verses.isEmpty {
            let sel = version.uppercased()
            if sel == "ESV" {
                if let esv = try? await fetchVersesFromESV(bookId: bookId, chapter: chapter), esv.isEmpty == false {
                    return esv
                } else {
                    throw NSError(domain: "BibleService", code: 1002, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load ESV verses. The ESV API is currently unavailable or returned no content for this passage."
                    ])
                }
            } else if sel == "NLT" {
                if let nlt = try? await fetchVersesFromNLT(bookId: bookId, chapter: chapter), nlt.isEmpty == false {
                    return nlt
                } else {
                    throw NSError(domain: "BibleService", code: 1001, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load NLT verses. The NLT API is currently unavailable or returned no content for this passage."
                    ])
                }
            } else if sel == "KJV" {
                if let kjv = try? await fetchVersesFromPublicAPI(bookId: bookId, chapter: chapter, translation: "kjv"), kjv.isEmpty == false {
                    return kjv
                } else {
                    throw NSError(domain: "BibleService", code: 1003, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to load KJV verses. The KJV API is currently unavailable or returned no content for this passage."
                    ])
                }
            }
            if let fallback = try? await fetchVersesFromPublicAPI(bookId: bookId, chapter: chapter), fallback.isEmpty == false {
                return fallback.map { BibleVerse(id: $0.id, book_id: $0.book_id, chapter: $0.chapter, verse: $0.verse, text: $0.text, version: version, heading: $0.heading) }
            }
        }
        return verses
    }

    // MARK: - Fallback to public API if Supabase has gaps
    private func fetchVersesFromPublicAPI(bookId: Int, chapter: Int, translation: String = "web") async throws -> [BibleVerse] {
        guard let name = getBookName(byId: bookId) else { return [] }
        let queryName = name.replacingOccurrences(of: " ", with: "+")
        let urlString = "https://bible-api.com/\(queryName)+\(chapter)?translation=\(translation.lowercased())"
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        struct APIResp: Codable { struct APIVerse: Codable { let verse: Int; let text: String }
            let verses: [APIVerse]
        }
        let api = try JSONDecoder().decode(APIResp.self, from: data)
        let version = translation.uppercased()
        var out: [BibleVerse] = []
        for (index, v) in api.verses.enumerated() {
            let id = (bookId * 10_000_000) + (chapter * 10_000) + v.verse * 10 + index
            out.append(BibleVerse(id: id, book_id: bookId, chapter: chapter, verse: v.verse, text: v.text.trimmingCharacters(in: .whitespacesAndNewlines), version: version, heading: nil))
        }
        return out
    }

    // MARK: - ESV API (Crossway)
    // Requires ESV API Key in Info.plist or environment under key "ESV_API_KEY".
    private func fetchVersesFromESV(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        guard let name = getBookName(byId: bookId) else { return [] }
        let apiKey = (
            Bundle.main.object(forInfoDictionaryKey: "ESV_API_KEY") as? String
        ) ?? UserDefaults.standard.string(forKey: "ESV_API_KEY")
        ?? ProcessInfo.processInfo.environment["ESV_API_KEY"]
        ?? BibleService.loadESVKeyFromBundle()
        guard let key = apiKey, key.isEmpty == false else {
            print("❌ ESV API key not found")
            return []
        }
        print("🔑 ESV API key found: \(key.prefix(10))...")
        let ref = "\(name) \(chapter)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var req = URLRequest(url: URL(string: "https://api.esv.org/v3/passage/text/?q=\(ref)&include-verse-numbers=true&include-passage-references=false&include-headings=false&include-footnotes=false")!)
        req.addValue("Token \(key)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable { let passages: [String] }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = r.passages.first else { return [] }
        // Normalize unicode punctuation and whitespace
        let normalized = text
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // ESV may include verse markers like "[1]" or inline numbers. Support both.
        let ns = normalized as NSString
        let bracketPattern = "\\[(\\d{1,3})\\]" // [1], [2], ...
        let plainPattern = "(?:(?<=^)|(?<=\\s))(\\d{1,3})(?=\\s)" // 1 , 2 , ...
        let regex = (try? NSRegularExpression(pattern: bracketPattern)) ?? (try! NSRegularExpression(pattern: plainPattern))
        let matches = regex.matches(in: normalized, options: [], range: NSRange(location: 0, length: ns.length))
        var verses: [BibleVerse] = []
        if matches.isEmpty == false {
            for (i, m) in matches.enumerated() {
                let numberStr = ns.substring(with: m.range(at: 1))
                let number = Int(numberStr) ?? (i + 1)
                let start = m.range.location + m.range.length
                let end = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
                var slice = ns.substring(with: NSRange(location: start, length: end - start))
                // Remove any accidental leading bracket or number artifacts
                slice = slice.replacingOccurrences(of: "^\\s*\\[(\\d{1,3})\\]\\s*", with: "", options: .regularExpression)
                slice = slice.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = (bookId * 10_000_000) + (chapter * 10_000) + (number * 10) + i
                verses.append(BibleVerse(id: id, book_id: bookId, chapter: chapter, verse: number, text: slice, version: "ESV", heading: nil))
            }
        }
        // If still empty, fallback to splitting on \n[\n] with a looser heuristic
        if verses.isEmpty {
            // Try to carve out after "[1]" if present
            if let firstRange = normalized.range(of: "[1]") {
                let tail = String(normalized[firstRange.lowerBound...])
                let parts = tail.components(separatedBy: "[")
                var built: [BibleVerse] = []
                for part in parts {
                    // expected like "1] text ..."
                    if let close = part.firstIndex(of: "]") {
                        let numStr = String(part[..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let rest = String(part[part.index(after: close)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if let n = Int(numStr) {
                            let id = (bookId * 10_000_000) + (chapter * 10_000) + (n * 10) + built.count
                            built.append(BibleVerse(id: id, book_id: bookId, chapter: chapter, verse: n, text: rest, version: "ESV", heading: nil))
                        }
                    }
                }
                verses = built
            }
        }
        return verses
    }

    // Attempt to load ESV key from a bundled env file and cache it in UserDefaults.
    private static func loadESVKeyFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: "ESVAPI", withExtension: "env") else { return nil }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        // Accept formats like: "ESV_API_KEY=abcdef" or "ESV API = abcdef"
        let lines = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines {
            if line.isEmpty { continue }
            if let eq = line.firstIndex(of: "=") {
                let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                if value.isEmpty == false {
                    UserDefaults.standard.set(value, forKey: "ESV_API_KEY")
                    return value
                }
            } else {
                // If no '=', take the whole line if it looks like a hex token
                let token = line.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
                if token.count >= 32 {
                    UserDefaults.standard.set(token, forKey: "ESV_API_KEY")
                    return token
                }
            }
        }
        return nil
    }

    // MARK: - NLT API (api.nlt.to) minimal support
    private func fetchVersesFromNLT(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        guard let name = getBookName(byId: bookId) else { return [] }
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "NLT_API_KEY") as? String)
            ?? UserDefaults.standard.string(forKey: "NLT_API_KEY")
            ?? ProcessInfo.processInfo.environment["NLT_API_KEY"]
            ?? BibleService.loadNLTKeyFromBundle()
        guard let key = apiKey, key.isEmpty == false else {
            print("❌ NLT API key not found")
            return []
        }
        print("🔑 NLT API key found: \(key.prefix(10))...")

        // NLT unofficial API expects ref with dot separator and returns HTML-like text
        let ref = ("\(name) \(chapter)")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: ".")
        let urlStr = "https://api.nlt.to/api/passages?ref=\(ref)&key=\(key)"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        // Strip basic tags and normalize
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Split verses using a broad pattern: bracketed/parenthesized or superscript-like numbers
        let ns = stripped as NSString
        let pattern = "(?:(?<=^)|(?<=\\s))[\\(\\[]?(\\d{1,3})[\\)\\]]?\\s"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: stripped, range: NSRange(location: 0, length: ns.length))
        var verses: [BibleVerse] = []
        for (i, m) in matches.enumerated() {
            let numberStr = ns.substring(with: m.range(at: 1))
            let number = Int(numberStr) ?? (i + 1)
            let start = m.range.location + m.range.length
            let end = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
            let slice = ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
            let id = (bookId * 10_000_000) + (chapter * 10_000) + (number * 10) + i
            verses.append(BibleVerse(id: id, book_id: bookId, chapter: chapter, verse: number, text: slice, version: "NLT", heading: nil))
        }
        return verses
    }

    private static func loadNLTKeyFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: "NLTAPI", withExtension: "env") else { return nil }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        for line in lines {
            if line.isEmpty { continue }
            if let eq = line.firstIndex(of: "=") {
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                let normalizedKey = key.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression).uppercased()
                if normalizedKey.contains("NLT") && value.isEmpty == false {
                    UserDefaults.standard.set(value, forKey: "NLT_API_KEY")
                    return value
                }
            } else {
                let token = line.replacingOccurrences(of: "[^A-Za-z0-9-]", with: "", options: .regularExpression)
                if token.count >= 16 {
                    UserDefaults.standard.set(token, forKey: "NLT_API_KEY")
                    return token
                }
            }
        }
        return nil
    }

    // MARK: - API.Bible (NLT) support
    private static func nltAPIBibleId() -> String? {
        // Allow configuration via Info.plist or env under NLT_BIBLE_ID (default to known NLT id)
        if let v = Bundle.main.object(forInfoDictionaryKey: "NLT_BIBLE_ID") as? String, v.isEmpty == false { return v }
        if let v = ProcessInfo.processInfo.environment["NLT_BIBLE_ID"], v.isEmpty == false { return v }
        // Default NLT Bible ID for api.bible (commonly used): 06125adad2d5898a-01
        return "06125adad2d5898a-01"
    }

    private func fetchVersesFromAPIBible(bookId: Int, chapter: Int, translationId: String?) async throws -> [BibleVerse] {
        guard let translationId else { return [] }
        // API key for api.bible
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "APIBIBLE_API_KEY") as? String)
            ?? UserDefaults.standard.string(forKey: "APIBIBLE_API_KEY")
            ?? ProcessInfo.processInfo.environment["APIBIBLE_API_KEY"]
        guard let key = apiKey, key.isEmpty == false else { return [] }

        // Map our numeric bookId to USFM codes expected by API.Bible
        guard let usfm = Self.usfmCode(for: bookId) else { return [] }
        let chapterId = "\(translationId):\(usfm).\(chapter)"
        var req = URLRequest(url: URL(string: "https://api.scripture.api.bible/v1/bibles/\(translationId)/chapters/\(chapterId)?content-type=text&include-notes=false&include-titles=false&include-chapter-numbers=false&include-verse-numbers=true")!)
        req.addValue(key, forHTTPHeaderField: "api-key")
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Resp: Codable { struct DataNode: Codable { let content: String }; let data: DataNode }
        let r = try JSONDecoder().decode(Resp.self, from: data)
        let html = r.data.content
        // Strip tags and split by verse numbers (like 1, 2, ...)
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = stripped as NSString
        let pattern = "(?:(?<=^)|(?<=\\s))(\\d{1,3})(?=\\s)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: stripped, range: NSRange(location: 0, length: ns.length))
        var verses: [BibleVerse] = []
        for (i, m) in matches.enumerated() {
            let numberStr = ns.substring(with: m.range(at: 1))
            let number = Int(numberStr) ?? (i + 1)
            let start = m.range.location + m.range.length
            let end = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
            let slice = ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
            let id = (bookId * 10_000_000) + (chapter * 10_000) + (number * 10) + i
            verses.append(BibleVerse(id: id, book_id: bookId, chapter: chapter, verse: number, text: slice, version: "NLT", heading: nil))
        }
        return verses
    }

    // Removed: loadAPIBibleKeyFromBundle() because API.BIBLE.env is no longer used

    private static func usfmCode(for bookId: Int) -> String? {
        // Minimal USFM mapping for 66-book canon
        let map: [Int: String] = [
            1:"GEN",2:"EXO",3:"LEV",4:"NUM",5:"DEU",6:"JOS",7:"JDG",8:"RUT",9:"1SA",10:"2SA",
            11:"1KI",12:"2KI",13:"1CH",14:"2CH",15:"EZR",16:"NEH",17:"EST",18:"JOB",19:"PSA",20:"PRO",
            21:"ECC",22:"SNG",23:"ISA",24:"JER",25:"LAM",26:"EZK",27:"DAN",28:"HOS",29:"JOL",30:"AMO",
            31:"OBA",32:"JON",33:"MIC",34:"NAM",35:"HAB",36:"ZEP",37:"HAG",38:"ZEC",39:"MAL",
            40:"MAT",41:"MRK",42:"LUK",43:"JHN",44:"ACT",45:"ROM",46:"1CO",47:"2CO",48:"GAL",49:"EPH",
            50:"PHP",51:"COL",52:"1TH",53:"2TH",54:"1TI",55:"2TI",56:"TIT",57:"PHM",58:"HEB",59:"JAS",
            60:"1PE",61:"2PE",62:"1JN",63:"2JN",64:"3JN",65:"JUD",66:"REV"
        ]
        return map[bookId]
    }

    // Fetch footnotes for a verse (if you store them in a table called footnotes)
    func fetchFootnotes(bookId: Int, chapter: Int, verse: Int) async throws -> [Footnote] {
        let response = try await client
            .from("footnotes")
            .select()
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("verse", value: verse)
            .order("id", ascending: true)
            .execute()
        var notes = try JSONDecoder().decode([Footnote].self, from: response.data)
        // Sanitize note text to remove artifacts like "line_break"
        notes = notes.map { n in
            let cleaned = BibleService.sanitize(text: n.text)
            return Footnote(id: n.id, book_id: n.book_id, chapter: n.chapter, verse: n.verse, marker: n.marker, text: cleaned)
        }
        return notes
    }

    // Fetch only the first footnote text if available (used for showing the chip conditionally)
    func fetchFirstFootnoteText(bookId: Int, chapter: Int, verse: Int) async throws -> String? {
        let response = try await client
            .from("footnotes")
            .select("text")
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("verse", value: verse)
            .limit(1)
            .execute()
        struct Row: Codable { let text: String }
        let rows = try JSONDecoder().decode([Row].self, from: response.data)
        return rows.first?.text
    }

    // Server-side search (version-stable): case-insensitive substring match via ILIKE
    // This avoids SDK signature drift seen with textSearch on 2.31.x
    func searchVerses(query: String) async throws -> [BibleVerse] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        // First try selected translation
        let response = try await client
            .from("verses")
            .select()
            .ilike("text", pattern: "%\(trimmed)%")
            .eq("version", value: TranslationService.shared.version)
            .order("book_id", ascending: true)
            .order("chapter", ascending: true)
            .order("verse", ascending: true)
            .execute()

        var verses = try JSONDecoder().decode([BibleVerse].self, from: response.data)
        if verses.isEmpty {
            // Cross-version fallback
            let allResp = try await client
                .from("verses")
                .select()
                .ilike("text", pattern: "%\(trimmed)%")
                .order("book_id", ascending: true)
                .order("chapter", ascending: true)
                .order("verse", ascending: true)
                .execute()
            verses = try JSONDecoder().decode([BibleVerse].self, from: allResp.data)
        }

        // Phrase shortcuts for common queries
        if verses.isEmpty {
            if let ref = Self.phraseShortcuts[trimmed.lowercased()] {
                if let v = try? await fetchSpecificVerse(bookId: ref.bookId, chapter: ref.chapter, verse: ref.verse, version: TranslationService.shared.version) {
                    return [v]
                }
            }
        }
        verses = verses.map { v in
            let cleanedText = BibleService.sanitize(text: v.text)
            let cleanedHeading = v.heading.map { BibleService.sanitize(text: $0) }
            return BibleVerse(id: v.id, book_id: v.book_id, chapter: v.chapter, verse: v.verse, text: cleanedText, version: v.version, heading: cleanedHeading)
        }
        return verses
    }

    private func fetchSpecificVerse(bookId: Int, chapter: Int, verse: Int, version: String) async throws -> BibleVerse {
        let response = try await client
            .from("verses")
            .select()
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("verse", value: verse)
            .eq("version", value: version)
            .limit(1)
            .execute()
        let rows = try JSONDecoder().decode([BibleVerse].self, from: response.data)
        if let first = rows.first { return first }
        // Fallback across versions
        let anyResp = try await client
            .from("verses")
            .select()
            .eq("book_id", value: bookId)
            .eq("chapter", value: chapter)
            .eq("verse", value: verse)
            .limit(1)
            .execute()
        let anyRows = try JSONDecoder().decode([BibleVerse].self, from: anyResp.data)
        return anyRows.first ?? BibleVerse(id: -1, book_id: bookId, chapter: chapter, verse: verse, text: "", version: version, heading: nil)
    }

    private static let phraseShortcuts: [String: (bookId: Int, chapter: Int, verse: Int)] = [
        "jesus wept": (bookId: 43, chapter: 11, verse: 35) // John 11:35
    ]

    // Test connection to Supabase
    func testConnection() async throws -> Bool {
        do {
            _ = try await client
                .from("books")
                .select("count")
                .limit(1)
                .execute()
            return true
        } catch {
            print("Supabase connection test failed: \(error)")
            return false
        }
    }

    static func sanitize(text: String) -> String {
        // Remove artifacts and normalize spaces while preserving punctuation for accuracy
        var t = text
        // Drop explicit tokens like "line_break" and remove inline occurrences (case-insensitive)
        let lowered = t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "line_break" { return "" }
        t = t.replacingOccurrences(of: "line_break", with: " ", options: [.caseInsensitive])
        t = t.replacingOccurrences(of: "[object Object]", with: "")
        t = t.replacingOccurrences(of: "\n", with: " ")
        // Remove leading NLT disclaimer markers like "* 13:1 Verses ..." if present
        // Use raw string to avoid Swift escape issues
        if let regex = try? NSRegularExpression(
            pattern: #"^\s*\*?\s*(?:\d{1,3}:\d{1,3}\s*)?(?:(?:Verses|In Hebrew|Hebrew|Greek)\b).*?[—-]?\s*"#,
            options: [.caseInsensitive]
        ) {
            let ns = t as NSString
            let full = NSRange(location: 0, length: ns.length)
            if let m = regex.firstMatch(in: t, options: [], range: full), m.range.length > 0 {
                let start = m.range.location + m.range.length
                if start < ns.length {
                    t = ns.substring(from: start)
                }
            }
        }
        
        if let regex = try? NSRegularExpression(
            pattern: #"\s*(?:Greek|Hebrew|Aramaic|Latin)\s+[^.]+?(?:also in|or|and|;)[^.]+?\."#,
            options: [.caseInsensitive]
        ) {
            t = regex.stringByReplacingMatches(in: t, options: [], range: NSRange(location: 0, length: (t as NSString).length), withTemplate: "")
        }
        
        t = t.replacingOccurrences(of: #"\s*\*\s*\d{1,3}:\d{0,3}\s*"#, with: " ", options: .regularExpression)
        
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return t
    }

    private static func containsReadableContent(_ text: String) -> Bool {
        // Exclude token-only strings like "line_break"
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "line_break" { return false }
        // Must contain at least one letter or digit (Unicode aware)
        return text.range(of: "[\\p{L}\\p{N}]", options: .regularExpression) != nil
    }

    // Attempt to split an inline heading from the start of verse text.
    // Examples it handles:
    // "Dead to Sin, Alive to God What then shall we say? ..."
    // "Slaves to Righteousness What then? Shall we sin ..."
    // Strategy: if there is a capitalized phrase at the start followed by two spaces or by a capital word then a question/statement start like "What", "Then", "And", we split.
    static func extractInlineHeading(from text: String) -> (heading: String?, body: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the text starts with a long Title Case segment followed by two or more spaces or a known segue token, treat it as heading.
        // Use a relaxed regex: ^([A-Z][^a-z\d]*[A-Za-z,\-\s']{8,}?)\s{2,}(.+)$
        if let regex = try? NSRegularExpression(pattern: "^([A-Z][A-Za-z0-9,'’\\-\\s]{6,}?)\\s{2,}(.+)$") {
            let range = NSRange(location: 0, length: (t as NSString).length)
            if let m = regex.firstMatch(in: t, options: [], range: range), m.numberOfRanges == 3 {
                let h = (t as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let body = (t as NSString).substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
                if h.split(separator: " ").count >= 2 { return (h, body) }
            }
        }
        // Fallback: split before typical segue tokens when preceding segment looks like a title (contains 2+ words, mostly capitalized)
        let tokens = ["What ", "Then ", "When ", "After ", "And ", "But ", "Therefore ", "So "]
        for token in tokens {
            if let r = t.range(of: " " + token) { // a space then token
                let headingCandidate = String(t[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let body = String(t[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
                let words = headingCandidate.split(separator: " ")
                let capitalizedWordCount = words.filter { $0.first?.isUppercase == true }.count
                if words.count >= 2 && capitalizedWordCount >= words.count - 1 { return (headingCandidate, body) }
            }
        }
        return (nil, text)
    }

    // Resolve duplicate verse numbers intelligently.
    // If there are K rows labeled with verse N and verses N+1..N+K-1 do not exist,
    // treat them as misnumbered and split into sequential verses N..N+K-1.
    // Otherwise (true duplicates), merge their texts into a single verse N.
    private static func resolveDuplicateVerses(_ verses: [BibleVerse]) -> [BibleVerse] {
        if verses.isEmpty { return verses }
        var result: [BibleVerse] = []
        let numbersSet = Set(verses.map { $0.verse })
        let byNumber = Dictionary(grouping: verses, by: { $0.verse })
        for (n, group) in byNumber {
            if group.count == 1 {
                result.append(group[0])
                continue
            }
            let sorted = group.sorted { (a, b) in
                if a.verse == b.verse { return a.id < b.id }
                return a.verse < b.verse
            }
            // Determine if following verse numbers exist already
            var followingExists = false
            if sorted.count > 1 {
                for i in 1..<sorted.count {
                    if numbersSet.contains(n + i) { followingExists = true; break }
                }
            }
            if followingExists {
                // True duplicates → prefer a single canonical variant (avoid duplication of near-identical texts)
                // Preference order: BSB version (if present) > longest non-empty text
                let preferred: BibleVerse = {
                    if let bsb = sorted.first(where: { $0.version.uppercased().contains("BSB") }) { return bsb }
                    return sorted.max(by: { normalizeForComparison($0.text).count < normalizeForComparison($1.text).count }) ?? sorted.first!
                }()
                result.append(BibleVerse(id: preferred.id, book_id: preferred.book_id, chapter: preferred.chapter, verse: preferred.verse, text: preferred.text, version: preferred.version, heading: preferred.heading))
            } else {
                // Misnumbered block → split into sequential verses
                for (idx, v) in sorted.enumerated() {
                    let newNumber = n + idx
                    let newId = (v.book_id * 10_000_000) + (v.chapter * 10_000) + (newNumber * 10) + (v.id % 10)
                    result.append(BibleVerse(id: newId, book_id: v.book_id, chapter: v.chapter, verse: newNumber, text: v.text, version: v.version, heading: idx == 0 ? v.heading : nil))
                }
            }
        }
        result.sort { (a, b) in
            if a.verse == b.verse { return a.id < b.id }
            return a.verse < b.verse
        }
        return result
    }

    private static func normalizeForComparison(_ text: String) -> String {
        var t = text.lowercased()
        t = t.replacingOccurrences(of: "\\[[a-z]\\]", with: "", options: .regularExpression) // drop footnote markers like [a]
        t = t.replacingOccurrences(of: "[^a-z0-9\n\r\t ]", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Ensure verse numbers are contiguous within a chapter by inserting placeholder rows
    // for any missing numbers between the smallest and largest numbers present.
    // Placeholders have empty text and no heading so they won't affect VOTD selection
    // and will visibly show the verse number slot in the UI.
    private static func normalizeContiguousNumbering(verses: [BibleVerse], bookId: Int, chapter: Int) -> [BibleVerse] {
        guard verses.isEmpty == false else { return verses }
        var normalized: [BibleVerse] = []
        let versionName: String = verses.first?.version ?? ""

        var previousVerseNumber: Int? = nil
        for verse in verses {
            if let prev = previousVerseNumber {
                if verse.verse > prev + 1 {
                    // Insert placeholders for missing numbers between prev and current-1
                    let missingStart = prev + 1
                    let missingEnd = verse.verse - 1
                    if missingStart <= missingEnd {
                        for missing in missingStart...missingEnd {
                            // Compose a deterministic synthetic id that won't collide with DB ids
                            // and remains stable across runs (similar to public API fallback scheme)
                            let syntheticId = (bookId * 10_000_000) + (chapter * 10_000) + (missing * 10) + 9
                            let placeholder = BibleVerse(
                                id: syntheticId,
                                book_id: bookId,
                                chapter: chapter,
                                verse: missing,
                                text: "",
                                version: versionName,
                                heading: nil
                            )
                            normalized.append(placeholder)
                        }
                    }
                }
            } else {
                // If the first verse number isn't 1, fill from 1..first-1
                if verse.verse > 1 {
                    for missing in 1..<(verse.verse) {
                        let syntheticId = (bookId * 10_000_000) + (chapter * 10_000) + (missing * 10) + 9
                        let placeholder = BibleVerse(
                            id: syntheticId,
                            book_id: bookId,
                            chapter: chapter,
                            verse: missing,
                            text: "",
                            version: versionName,
                            heading: nil
                        )
                        normalized.append(placeholder)
                    }
                }
            }
            normalized.append(verse)
            previousVerseNumber = verse.verse
        }
        // Already contiguous up to the last available verse. We do not guess the true max.
        return normalized
    }
}
