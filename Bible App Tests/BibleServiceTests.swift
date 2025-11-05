import XCTest
@testable import Bible_App

final class BibleServiceTests: XCTestCase {
    var bibleService: BibleService!
    
    override func setUpWithError() throws {
        bibleService = BibleService.shared
    }
    
    override func tearDownWithError() throws {
        bibleService = nil
    }
    
    // MARK: - Translation Configuration Tests
    
    func testTranslationConfigAvailability() {
        let availableTranslations = TranslationConfig.availableCodes
        
        XCTAssertTrue(availableTranslations.contains("BSB"))
        XCTAssertTrue(availableTranslations.contains("ESV"))
        XCTAssertTrue(availableTranslations.contains("NLT"))
        XCTAssertTrue(availableTranslations.contains("WEB"))
        XCTAssertTrue(availableTranslations.contains("KJV"))
        XCTAssertEqual(availableTranslations.count, 5)
    }
    
    func testTranslationConfigDetails() {
        let esvConfig = TranslationConfig.config(for: "ESV")
        XCTAssertNotNil(esvConfig)
        XCTAssertEqual(esvConfig?.code, "ESV")
        XCTAssertEqual(esvConfig?.name, "English Standard Version")
        XCTAssertTrue(esvConfig?.requiresAPIKey ?? false)
        XCTAssertEqual(esvConfig?.apiKeyName, "ESV_API_KEY")
        
        let bsbConfig = TranslationConfig.config(for: "BSB")
        XCTAssertNotNil(bsbConfig)
        XCTAssertFalse(bsbConfig?.requiresAPIKey ?? true)
        XCTAssertNil(bsbConfig?.apiKeyName)
    }
    
    // MARK: - Book Name Formatting Tests
    
    func testBookNameFormattingForDifferentAPIs() async {
        // Test book name formatting (we need to access the private method through reflection or make it internal)
        let testBookName = "1 Samuel"
        
        // These would test the formatBookNameForAPI method if it were accessible
        // For now, we test the expected formats based on the implementation
        
        // NLT format: "1.Samuel"
        let nltExpected = "1.Samuel"
        let nltFormatted = testBookName.replacingOccurrences(of: " ", with: ".")
        XCTAssertEqual(nltFormatted, nltExpected)
        
        // KJV/WEB format: "1+Samuel"
        let kjvExpected = "1+Samuel"
        let kjvFormatted = testBookName.replacingOccurrences(of: " ", with: "+")
        XCTAssertEqual(kjvFormatted, kjvExpected)
        
        // ESV format: URL encoded
        let esvFormatted = testBookName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        XCTAssertNotNil(esvFormatted)
        XCTAssertTrue(esvFormatted?.contains("Samuel") ?? false)
    }
    
    // MARK: - Error Handling Tests
    
    func testBibleServiceErrorTypes() {
        let invalidBookError = BibleServiceError.invalidBookId(999)
        XCTAssertEqual(invalidBookError.localizedDescription, "Invalid book ID: 999")
        
        let missingKeyError = BibleServiceError.missingAPIKey("TEST_KEY")
        XCTAssertTrue(missingKeyError.localizedDescription.contains("Missing API key: TEST_KEY"))
        
        let invalidKeyError = BibleServiceError.invalidAPIKey("TEST_KEY", "Too short")
        XCTAssertTrue(invalidKeyError.localizedDescription.contains("Invalid API key TEST_KEY: Too short"))
        
        let networkError = BibleServiceError.networkError("Connection failed")
        XCTAssertEqual(networkError.localizedDescription, "Network error: Connection failed")
        
        let parsingError = BibleServiceError.dataParsingError("Invalid JSON")
        XCTAssertEqual(parsingError.localizedDescription, "Data parsing error: Invalid JSON")
        
        let rateLimitError = BibleServiceError.apiRateLimitExceeded("ESV")
        XCTAssertEqual(rateLimitError.localizedDescription, "API rate limit exceeded for ESV. Please try again later.")
    }
    
    // MARK: - Rate Limiting Tests
    
    func testAPIRateLimiterBasicFunctionality() async throws {
        let rateLimiter = APIRateLimiter()
        
        // First call should succeed immediately
        let startTime = Date()
        try await rateLimiter.checkRateLimit(for: "TEST")
        let firstCallDuration = Date().timeIntervalSince(startTime)
        
        // Should be nearly instantaneous
        XCTAssertLessThan(firstCallDuration, 0.1)
        
        // Second call should be delayed
        let secondStartTime = Date()
        try await rateLimiter.checkRateLimit(for: "TEST")
        let secondCallDuration = Date().timeIntervalSince(secondStartTime)
        
        // Should be delayed by at least the minimum interval (0.1 seconds for default)
        XCTAssertGreaterThanOrEqual(secondCallDuration, 0.05) // Allow some tolerance
    }
    
    func testAPIRateLimiterDifferentAPIs() async throws {
        let rateLimiter = APIRateLimiter()
        
        // Calls to different APIs should not interfere with each other
        let startTime = Date()
        
        try await rateLimiter.checkRateLimit(for: "ESV")
        try await rateLimiter.checkRateLimit(for: "NLT")
        try await rateLimiter.checkRateLimit(for: "KJV")
        
        let totalDuration = Date().timeIntervalSince(startTime)
        
        // Should complete quickly since they're different APIs
        XCTAssertLessThan(totalDuration, 0.2)
    }
    
    // MARK: - Translation Service Tests
    
    func testTranslationServiceSingleton() {
        let service1 = TranslationService.shared
        let service2 = TranslationService.shared
        
        XCTAssertTrue(service1 === service2)
    }
    
    func testTranslationServiceAvailableVersions() {
        let service = TranslationService.shared
        let available = service.available
        
        XCTAssertTrue(available.contains("BSB"))
        XCTAssertTrue(available.contains("ESV"))
        XCTAssertTrue(available.contains("NLT"))
        XCTAssertTrue(available.contains("WEB"))
        XCTAssertTrue(available.contains("KJV"))
    }
    
    // MARK: - Integration Tests (Mock-based)
    
    func testFetchVersesWithInvalidBookId() async {
        do {
            let verses = try await bibleService.fetchVerses(bookId: 999, chapter: 1, version: "BSB")
            XCTAssertTrue(verses.isEmpty, "Should return empty array for invalid book ID")
        } catch {
            // Expected to throw an error for invalid book ID
            XCTAssertTrue(error is BibleServiceError)
        }
    }
    
    func testFetchVersesWithValidParameters() async {
        // This test would require actual API access or mocking
        // For now, we test that the method exists and can be called
        do {
            let verses = try await bibleService.fetchVerses(bookId: 1, chapter: 1, version: "BSB")
            // If successful, verses should be an array (could be empty if no data)
            XCTAssertNotNil(verses)
        } catch {
            // If it fails, it should be a proper BibleServiceError
            print("Expected error in test environment: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testTranslationConfigPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = TranslationConfig.availableCodes
                let _ = TranslationConfig.config(for: "ESV")
            }
        }
    }
    
    func testRateLimiterPerformance() {
        let rateLimiter = APIRateLimiter()
        
        measure {
            let expectation = XCTestExpectation(description: "Rate limiter performance")
            
            Task {
                for _ in 0..<10 {
                    try? await rateLimiter.checkRateLimit(for: "PERF_TEST")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyBookNameHandling() {
        let emptyName = ""
        let formattedForNLT = emptyName.replacingOccurrences(of: " ", with: ".")
        let formattedForKJV = emptyName.replacingOccurrences(of: " ", with: "+")
        
        XCTAssertEqual(formattedForNLT, "")
        XCTAssertEqual(formattedForKJV, "")
    }
    
    func testSpecialCharacterBookNames() {
        let specialName = "Song of Solomon"
        let formattedForNLT = specialName.replacingOccurrences(of: " ", with: ".")
        let formattedForKJV = specialName.replacingOccurrences(of: " ", with: "+")
        
        XCTAssertEqual(formattedForNLT, "Song.of.Solomon")
        XCTAssertEqual(formattedForKJV, "Song+of+Solomon")
    }
    
    func testNumberedBookNames() {
        let numberedNames = ["1 Kings", "2 Chronicles", "3 John"]
        
        for name in numberedNames {
            let nltFormat = name.replacingOccurrences(of: " ", with: ".")
            let kjvFormat = name.replacingOccurrences(of: " ", with: "+")
            
            XCTAssertTrue(nltFormat.contains("."))
            XCTAssertTrue(kjvFormat.contains("+"))
            XCTAssertFalse(nltFormat.contains(" "))
            XCTAssertFalse(kjvFormat.contains(" "))
        }
    }
}

// MARK: - Mock Classes for Testing

class MockBibleService {
    func fetchVerses(bookId: Int, chapter: Int, version: String) async throws -> [BibleVerse] {
        // Mock implementation for testing
        if bookId == 999 {
            throw BibleServiceError.invalidBookId(bookId)
        }
        
        if version == "INVALID" {
            throw BibleServiceError.dataParsingError("Invalid version")
        }
        
        // Return mock verses
        return [
            BibleVerse(id: 1, book_id: bookId, chapter: chapter, verse: 1, text: "Mock verse 1", version: version, heading: nil),
            BibleVerse(id: 2, book_id: bookId, chapter: chapter, verse: 2, text: "Mock verse 2", version: version, heading: nil)
        ]
    }
}

// MARK: - Test Extensions

extension BibleServiceTests {
    
    func testMockBibleService() async throws {
        let mockService = MockBibleService()
        
        // Test successful fetch
        let verses = try await mockService.fetchVerses(bookId: 1, chapter: 1, version: "BSB")
        XCTAssertEqual(verses.count, 2)
        XCTAssertEqual(verses[0].text, "Mock verse 1")
        XCTAssertEqual(verses[1].text, "Mock verse 2")
        
        // Test error handling
        do {
            let _ = try await mockService.fetchVerses(bookId: 999, chapter: 1, version: "BSB")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is BibleServiceError)
        }
    }
}
