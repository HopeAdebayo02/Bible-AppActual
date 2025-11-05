import Foundation
import UIKit

// MARK: - Bible Cache Service
class BibleCacheService {
    static let shared = BibleCacheService()
    
    private let cache = NSCache<NSString, CachedChapter>()
    private let cacheQueue = DispatchQueue(label: "bible-cache", attributes: .concurrent)
    private let maxCacheSize = 100 // Maximum number of chapters to cache
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour
    
    private init() {
        cache.countLimit = maxCacheSize
        setupMemoryWarningObserver()
    }
    
    // MARK: - Cache Key Generation
    private func cacheKey(bookId: Int, chapter: Int, version: String) -> String {
        return "\(version):\(bookId):\(chapter)"
    }
    
    // MARK: - Cache Operations
    func getCachedVerses(bookId: Int, chapter: Int, version: String) -> [BibleVerse]? {
        return cacheQueue.sync {
            let key = cacheKey(bookId: bookId, chapter: chapter, version: version)
            guard let cachedChapter = cache.object(forKey: NSString(string: key)) else {
                return nil
            }
            
            // Check if cache entry has expired
            if Date().timeIntervalSince(cachedChapter.timestamp) > cacheExpirationTime {
                cache.removeObject(forKey: NSString(string: key))
                return nil
            }
            
            return cachedChapter.verses
        }
    }
    
    func cacheVerses(_ verses: [BibleVerse], bookId: Int, chapter: Int, version: String) {
        cacheQueue.async(flags: .barrier) {
            let key = self.cacheKey(bookId: bookId, chapter: chapter, version: version)
            let cachedChapter = CachedChapter(verses: verses, timestamp: Date())
            self.cache.setObject(cachedChapter, forKey: NSString(string: key))
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
    
    func removeCachedChapter(bookId: Int, chapter: Int, version: String) {
        cacheQueue.async(flags: .barrier) {
            let key = self.cacheKey(bookId: bookId, chapter: chapter, version: version)
            self.cache.removeObject(forKey: NSString(string: key))
        }
    }
    
    // MARK: - Cache Statistics
    func getCacheInfo() -> (count: Int, limit: Int) {
        return cacheQueue.sync {
            return (count: cache.totalCostLimit, limit: maxCacheSize)
        }
    }
    
    // MARK: - Memory Management
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Cached Chapter Model
private class CachedChapter {
    let verses: [BibleVerse]
    let timestamp: Date
    
    init(verses: [BibleVerse], timestamp: Date) {
        self.verses = verses
        self.timestamp = timestamp
    }
}

// MARK: - BibleService Cache Integration
extension BibleService {
    
    // Enhanced fetchVerses with caching
    func fetchVersesWithCache(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        let selectedVersion = await TranslationService.shared.version.uppercased()
        
        // Try cache first
        if let cachedVerses = BibleCacheService.shared.getCachedVerses(
            bookId: bookId, 
            chapter: chapter, 
            version: selectedVersion
        ) {
            return cachedVerses
        }
        
        // Fetch from network/database
        let verses = try await fetchVerses(bookId: bookId, chapter: chapter)
        
        // Cache the results
        if !verses.isEmpty {
            BibleCacheService.shared.cacheVerses(
                verses, 
                bookId: bookId, 
                chapter: chapter, 
                version: selectedVersion
            )
        }
        
        return verses
    }
    
    func fetchVersesWithCache(bookId: Int, chapter: Int, version: String) async throws -> [BibleVerse] {
        let normalizedVersion = version.uppercased()
        
        // Try cache first
        if let cachedVerses = BibleCacheService.shared.getCachedVerses(
            bookId: bookId, 
            chapter: chapter, 
            version: normalizedVersion
        ) {
            return cachedVerses
        }
        
        // Fetch from network/database
        let verses = try await fetchVerses(bookId: bookId, chapter: chapter, version: version)
        
        // Cache the results
        if !verses.isEmpty {
            BibleCacheService.shared.cacheVerses(
                verses, 
                bookId: bookId, 
                chapter: chapter, 
                version: normalizedVersion
            )
        }
        
        return verses
    }
}

// MARK: - Cache Preloading Service
class BibleCachePreloader {
    static let shared = BibleCachePreloader()
    
    let preloadQueue = DispatchQueue(label: "bible-preload", qos: .background)
    
    private init() {}
    
    // Preload commonly accessed chapters
    func preloadPopularChapters() {
        preloadQueue.async {
            let popularChapters: [(bookId: Int, chapter: Int)] = [
                (1, 1),   // Genesis 1
                (19, 23), // Psalm 23
                (43, 3),  // John 3
                (45, 8),  // Romans 8
                (46, 13), // 1 Corinthians 13
                (40, 5),  // Matthew 5 (Sermon on the Mount)
            ]
            
            Task {
                for (bookId, chapter) in popularChapters {
                    do {
                        let _ = try await BibleService.shared.fetchVersesWithCache(
                            bookId: bookId, 
                            chapter: chapter
                        )
                        // Small delay to avoid overwhelming the system
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    } catch {
                        print("Failed to preload \(bookId):\(chapter) - \(error)")
                    }
                }
            }
        }
    }
    
    // Preload adjacent chapters for better navigation experience
    func preloadAdjacentChapters(bookId: Int, chapter: Int, version: String) {
        preloadQueue.async {
            Task {
                // Preload previous chapter
                if chapter > 1 {
                    try? await BibleService.shared.fetchVersesWithCache(
                        bookId: bookId, 
                        chapter: chapter - 1, 
                        version: version
                    )
                }
                
                // Preload next chapter (assuming reasonable chapter count)
                if chapter < 150 { // Max chapters in any book
                    try? await BibleService.shared.fetchVersesWithCache(
                        bookId: bookId, 
                        chapter: chapter + 1, 
                        version: version
                    )
                }
            }
        }
    }
}
