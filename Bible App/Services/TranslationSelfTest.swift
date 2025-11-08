import Foundation

class TranslationSelfTest {
    static let shared = TranslationSelfTest()
    
    struct TestResult {
        let translation: String
        let passage: String
        let success: Bool
        let verseCount: Int
        let source: String
        let error: String?
        let preview: String?
    }
    
    private init() {}
    
    private let testPassages: [(bookId: Int, chapter: Int, name: String)] = [
        (1, 1, "Genesis 1"),
        (2, 20, "Exodus 20"),
        (19, 23, "Psalm 23"),
        (23, 53, "Isaiah 53"),
        (40, 5, "Matthew 5"),
        (43, 3, "John 3"),
        (45, 8, "Romans 8")
    ]
    
    func runAllTests() async -> [TestResult] {
        var results: [TestResult] = []
        let translations = ["BSB", "ESV", "NLT", "WEB", "KJV"]
        
        print("🧪 Starting Translation Self-Test...")
        print("📋 Testing \(translations.count) translations across \(testPassages.count) passages")
        
        for translation in translations {
            print("\n🔍 Testing \(translation)...")
            
            for passage in testPassages {
                do {
                    let verses = try await BibleService.shared.fetchVerses(
                        bookId: passage.bookId,
                        chapter: passage.chapter,
                        selectedTranslation: translation
                    )
                    
                    let success = !verses.isEmpty
                    let preview = verses.first?.text.prefix(100).description
                    let source = determineSource(verses: verses, translation: translation)
                    
                    results.append(TestResult(
                        translation: translation,
                        passage: passage.name,
                        success: success,
                        verseCount: verses.count,
                        source: source,
                        error: success ? nil : "No verses returned",
                        preview: preview
                    ))
                    
                    if success {
                        print("  ✅ \(passage.name): \(verses.count) verses from \(source)")
                    } else {
                        print("  ❌ \(passage.name): FAILED - No verses")
                    }
                    
                } catch {
                    results.append(TestResult(
                        translation: translation,
                        passage: passage.name,
                        success: false,
                        verseCount: 0,
                        source: "ERROR",
                        error: error.localizedDescription,
                        preview: nil
                    ))
                    print("  ❌ \(passage.name): ERROR - \(error.localizedDescription)")
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        
        print("\n✅ Translation Self-Test Complete!")
        return results
    }
    
    private func determineSource(verses: [BibleVerse], translation: String) -> String {
        guard let firstVerse = verses.first else { return "UNKNOWN" }
        
        if firstVerse.version.uppercased().contains(translation.uppercased()) {
            if translation == "ESV" {
                return "ESV API"
            } else if translation == "NLT" {
                return "NLT API"
            } else if translation == "KJV" {
                return "bible-api.com"
            } else if translation == "WEB" {
                return "bible-api.com"
            } else {
                return "Supabase DB"
            }
        }
        
        return "Supabase DB"
    }
    
    func generateReport(results: [TestResult]) -> String {
        var report = "# Translation Self-Test Report\n\n"
        report += "Generated: \(Date())\n\n"
        report += "## Summary\n\n"
        
        let byTranslation = Dictionary(grouping: results) { $0.translation }
        
        for translation in ["BSB", "ESV", "NLT", "WEB", "KJV"] {
            guard let transResults = byTranslation[translation] else { continue }
            let successCount = transResults.filter { $0.success }.count
            let totalCount = transResults.count
            let percentage = (Double(successCount) / Double(totalCount)) * 100
            
            report += "### \(translation): \(successCount)/\(totalCount) passed (\(String(format: "%.1f", percentage))%)\n\n"
            
            for result in transResults {
                let icon = result.success ? "✅" : "❌"
                report += "- \(icon) **\(result.passage)**: "
                if result.success {
                    report += "\(result.verseCount) verses from \(result.source)\n"
                    if let preview = result.preview {
                        report += "  - Preview: \"\(preview)...\"\n"
                    }
                } else {
                    report += "FAILED - \(result.error ?? "Unknown error")\n"
                }
            }
            report += "\n"
        }
        
        let totalSuccess = results.filter { $0.success }.count
        let totalTests = results.count
        let overallPercentage = (Double(totalSuccess) / Double(totalTests)) * 100
        
        report += "## Overall Result\n\n"
        report += "**\(totalSuccess)/\(totalTests) tests passed (\(String(format: "%.1f", overallPercentage))%)**\n\n"
        
        if totalSuccess == totalTests {
            report += "🎉 All translations working correctly!\n"
        } else {
            report += "⚠️ Some translations have issues that need attention.\n"
        }
        
        return report
    }
}
