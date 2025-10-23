import Foundation
import SQLite3

// MARK: - Offline Bible Service
class OfflineBibleService {
    static let shared = OfflineBibleService()
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "offline-bible-db", qos: .userInitiated)
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        guard let dbPath = getDatabasePath() else {
            print("Failed to get database path")
            return
        }
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Failed to open offline Bible database")
            return
        }
        
        createTables()
    }
    
    private func getDatabasePath() -> String? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsPath.appendingPathComponent("offline_bible.db").path
    }
    
    private func createTables() {
        let createBooksTable = """
            CREATE TABLE IF NOT EXISTS offline_books (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                abbreviation TEXT,
                testament TEXT,
                chapters INTEGER NOT NULL
            );
        """
        
        let createVersesTable = """
            CREATE TABLE IF NOT EXISTS offline_verses (
                id INTEGER PRIMARY KEY,
                book_id INTEGER NOT NULL,
                chapter INTEGER NOT NULL,
                verse INTEGER NOT NULL,
                text TEXT NOT NULL,
                version TEXT NOT NULL,
                heading TEXT,
                FOREIGN KEY (book_id) REFERENCES offline_books (id)
            );
        """
        
        let createIndexes = """
            CREATE INDEX IF NOT EXISTS idx_verses_lookup ON offline_verses (book_id, chapter, version);
            CREATE INDEX IF NOT EXISTS idx_verses_number ON offline_verses (verse);
        """
        
        executeSQL(createBooksTable)
        executeSQL(createVersesTable)
        executeSQL(createIndexes)
    }
    
    private func executeSQL(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SQL Error: \(errorMessage)")
        }
    }
    
    // MARK: - Data Management
    
    func hasOfflineData(for version: String) -> Bool {
        return dbQueue.sync {
            let query = "SELECT COUNT(*) FROM offline_verses WHERE version = ? LIMIT 1"
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                return false
            }
            
            sqlite3_bind_text(statement, 1, version, -1, nil)
            
            let result = sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_int(statement, 0) > 0
            sqlite3_finalize(statement)
            
            return result
        }
    }
    
    func getOfflineBooks() -> [BibleBook] {
        return dbQueue.sync {
            var books: [BibleBook] = []
            let query = "SELECT id, name, abbreviation, testament, chapters FROM offline_books ORDER BY id"
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                return books
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int(statement, 0)
                let name = String(cString: sqlite3_column_text(statement, 1))
                let abbreviation = sqlite3_column_text(statement, 2) != nil ? String(cString: sqlite3_column_text(statement, 2)) : ""
                let testament = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : nil
                let chapters = sqlite3_column_int(statement, 4)
                
                let book = BibleBook(
                    id: Int(id),
                    name: name,
                    abbreviation: abbreviation,
                    testament: testament,
                    chapters: Int(chapters)
                )
                books.append(book)
            }
            
            sqlite3_finalize(statement)
            return books
        }
    }
    
    func getOfflineVerses(bookId: Int, chapter: Int, version: String) -> [BibleVerse] {
        return dbQueue.sync {
            var verses: [BibleVerse] = []
            let query = """
                SELECT id, book_id, chapter, verse, text, version, heading 
                FROM offline_verses 
                WHERE book_id = ? AND chapter = ? AND version = ? 
                ORDER BY verse
            """
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                return verses
            }
            
            sqlite3_bind_int(statement, 1, Int32(bookId))
            sqlite3_bind_int(statement, 2, Int32(chapter))
            sqlite3_bind_text(statement, 3, version, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int(statement, 0)
                let bookId = sqlite3_column_int(statement, 1)
                let chapter = sqlite3_column_int(statement, 2)
                let verse = sqlite3_column_int(statement, 3)
                let text = String(cString: sqlite3_column_text(statement, 4))
                let version = String(cString: sqlite3_column_text(statement, 5))
                let heading = sqlite3_column_text(statement, 6) != nil ? String(cString: sqlite3_column_text(statement, 6)) : nil
                
                let bibleVerse = BibleVerse(
                    id: Int(id),
                    book_id: Int(bookId),
                    chapter: Int(chapter),
                    verse: Int(verse),
                    text: text,
                    version: version,
                    heading: heading
                )
                verses.append(bibleVerse)
            }
            
            sqlite3_finalize(statement)
            return verses
        }
    }
    
    // MARK: - Data Import
    
    func importBooksFromSupabase(_ books: [BibleBook]) {
        dbQueue.async(flags: .barrier) {
            let insertSQL = "INSERT OR REPLACE INTO offline_books (id, name, abbreviation, testament, chapters) VALUES (?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                print("Failed to prepare books insert statement")
                return
            }
            
            for book in books {
                sqlite3_bind_int(statement, 1, Int32(book.id))
                sqlite3_bind_text(statement, 2, book.name, -1, nil)
                sqlite3_bind_text(statement, 3, book.abbreviation, -1, nil)
                sqlite3_bind_text(statement, 4, book.testament, -1, nil)
                sqlite3_bind_int(statement, 5, Int32(book.chapters))
                
                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Failed to insert book: \(book.name)")
                }
                
                sqlite3_reset(statement)
            }
            
            sqlite3_finalize(statement)
            print("Imported \(books.count) books to offline database")
        }
    }
    
    func importVersesFromSupabase(_ verses: [BibleVerse]) {
        dbQueue.async(flags: .barrier) {
            let insertSQL = "INSERT OR REPLACE INTO offline_verses (id, book_id, chapter, verse, text, version, heading) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var statement: OpaquePointer?
            
            guard sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
                print("Failed to prepare verses insert statement")
                return
            }
            
            for verse in verses {
                sqlite3_bind_int(statement, 1, Int32(verse.id))
                sqlite3_bind_int(statement, 2, Int32(verse.book_id))
                sqlite3_bind_int(statement, 3, Int32(verse.chapter))
                sqlite3_bind_int(statement, 4, Int32(verse.verse))
                sqlite3_bind_text(statement, 5, verse.text, -1, nil)
                sqlite3_bind_text(statement, 6, verse.version, -1, nil)
                sqlite3_bind_text(statement, 7, verse.heading, -1, nil)
                
                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Failed to insert verse: \(verse.book_id):\(verse.chapter):\(verse.verse)")
                }
                
                sqlite3_reset(statement)
            }
            
            sqlite3_finalize(statement)
            print("Imported \(verses.count) verses to offline database")
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
}

// MARK: - BibleService Offline Integration
extension BibleService {
    
    // Enhanced fetch with offline fallback
    func fetchVersesWithOfflineFallback(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        let selectedVersion = await TranslationService.shared.version.uppercased()
        
        // Try cache first
        if let cachedVerses = BibleCacheService.shared.getCachedVerses(
            bookId: bookId, 
            chapter: chapter, 
            version: selectedVersion
        ) {
            return cachedVerses
        }
        
        // Try online sources
        do {
            let verses = try await fetchVerses(bookId: bookId, chapter: chapter)
            
            // Cache successful results
            if !verses.isEmpty {
                BibleCacheService.shared.cacheVerses(verses, bookId: bookId, chapter: chapter, version: selectedVersion)
                
                // Also store in offline database for future use
                OfflineBibleService.shared.importVersesFromSupabase(verses)
            }
            
            return verses
        } catch {
            // If online fails, try offline
            print("Online fetch failed, trying offline: \(error)")
            return tryOfflineFallback(bookId: bookId, chapter: chapter, version: selectedVersion)
        }
    }
    
    private func tryOfflineFallback(bookId: Int, chapter: Int, version: String) -> [BibleVerse] {
        let offlineService = OfflineBibleService.shared
        
        // Check if we have offline data for this version
        guard offlineService.hasOfflineData(for: version) else {
            print("No offline data available for \(version)")
            return []
        }
        
        let offlineVerses = offlineService.getOfflineVerses(bookId: bookId, chapter: chapter, version: version)
        
        if !offlineVerses.isEmpty {
            print("Retrieved \(offlineVerses.count) verses from offline database")
            
            // Cache the offline results too
            BibleCacheService.shared.cacheVerses(offlineVerses, bookId: bookId, chapter: chapter, version: version)
        }
        
        return offlineVerses
    }
    
    // Proactive offline data sync
    func syncOfflineData() async {
        print("Starting offline data sync...")
        
        do {
            // Sync books first
            let books = try await fetchBooks()
            OfflineBibleService.shared.importBooksFromSupabase(books)
            
            // Sync popular chapters for BSB and WEB
            let popularChapters: [(bookId: Int, chapter: Int)] = [
                (1, 1),   // Genesis 1
                (19, 23), // Psalm 23
                (43, 3),  // John 3
                (45, 8),  // Romans 8
                (40, 5),  // Matthew 5
            ]
            
            for version in ["BSB", "WEB"] {
                for (bookId, chapter) in popularChapters {
                    do {
                        let verses = try await fetchVerses(bookId: bookId, chapter: chapter, version: version)
                        if !verses.isEmpty {
                            OfflineBibleService.shared.importVersesFromSupabase(verses)
                        }
                        
                        // Small delay to avoid overwhelming the system
                        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    } catch {
                        print("Failed to sync \(version) \(bookId):\(chapter) - \(error)")
                    }
                }
            }
            
            print("Offline data sync completed")
        } catch {
            print("Offline data sync failed: \(error)")
        }
    }
}
