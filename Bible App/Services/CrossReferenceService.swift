import Foundation

// MARK: - Cross Reference Models
struct CrossReference: Identifiable {
    let fromVerse: String
    let toVerse: String
    let votes: Int
    
    var id: String {
        "\(fromVerse)->\(toVerse)"
    }
    
    var fromBook: String {
        return String(fromVerse.split(separator: ".").first ?? "")
    }
    
    var fromChapter: Int {
        let parts = fromVerse.split(separator: ".")
        guard parts.count >= 2 else { return 0 }
        return Int(parts[1]) ?? 0
    }
    
    var fromVerseNumber: Int {
        let parts = fromVerse.split(separator: ".")
        guard parts.count >= 3 else { return 0 }
        return Int(parts[2]) ?? 0
    }
    
    var toBook: String {
        return String(toVerse.split(separator: ".").first ?? "")
    }
    
    var toChapter: Int {
        let parts = toVerse.split(separator: ".")
        guard parts.count >= 2 else { return 0 }
        return Int(parts[1]) ?? 0
    }
    
    var toVerseNumber: Int {
        let parts = toVerse.split(separator: ".")
        guard parts.count >= 3 else { return 0 }
        // Handle ranges like "John.1.1-John.1.3"
        let verseString = String(parts[2])
        if verseString.contains("-") {
            return Int(verseString.split(separator: "-").first ?? "0") ?? 0
        }
        return Int(verseString) ?? 0
    }
    
    var toVerseEndNumber: Int? {
        let parts = toVerse.split(separator: ".")
        guard parts.count >= 3 else { return nil }
        let verseString = String(parts[2])
        if verseString.contains("-") {
            let rangeParts = verseString.split(separator: "-")
            if rangeParts.count == 2 {
                return Int(rangeParts[1]) ?? nil
            }
        }
        return nil
    }
    
    var displayText: String {
        if let endVerse = toVerseEndNumber {
            return "\(toBook) \(toChapter):\(toVerseNumber)-\(endVerse)"
        } else {
            return "\(toBook) \(toChapter):\(toVerseNumber)"
        }
    }
}

// MARK: - Cross Reference Service
class CrossReferenceService {
    static let shared = CrossReferenceService()
    
    private var crossReferences: [CrossReference] = []
    private var isLoaded = false
    
    private init() {
        loadCrossReferences()
    }
    
    // MARK: - Loading Cross References
    private func loadCrossReferences() {
        guard !isLoaded else { return }
        
        guard let path = Bundle.main.path(forResource: "cross_references", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            print("Failed to load cross_references.txt")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            // Skip header line and empty lines
            if index == 0 || line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let components = line.components(separatedBy: "\t")
            guard components.count >= 3 else { continue }
            
            let fromVerse = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let toVerse = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let votes = Int(components[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            let crossRef = CrossReference(fromVerse: fromVerse, toVerse: toVerse, votes: votes)
            crossReferences.append(crossRef)
        }
        
        isLoaded = true
        print("Loaded \(crossReferences.count) cross references")
    }
    
    // MARK: - Public Methods
    func getCrossReferences(for bookName: String, chapter: Int, verse: Int) -> [CrossReference] {
        let bookAbbrev = getBookAbbreviation(for: bookName)
        let verseKey = "\(bookAbbrev).\(chapter).\(verse)"
        
        return crossReferences.filter { $0.fromVerse == verseKey }
            .sorted { $0.votes > $1.votes } // Sort by popularity (votes)
    }
    
    func getReferencesToVerse(for bookName: String, chapter: Int, verse: Int) -> [CrossReference] {
        let bookAbbrev = getBookAbbreviation(for: bookName)
        let verseKey = "\(bookAbbrev).\(chapter).\(verse)"
        
        return crossReferences.filter { $0.toVerse == verseKey }
            .sorted { $0.votes > $1.votes }
    }
    
    // MARK: - Book Name Mapping
    private func getBookAbbreviation(for fullName: String) -> String {
        let bookMappings: [String: String] = [
            "Genesis": "Gen",
            "Exodus": "Exod",
            "Leviticus": "Lev",
            "Numbers": "Num",
            "Deuteronomy": "Deut",
            "Joshua": "Josh",
            "Judges": "Judg",
            "Ruth": "Ruth",
            "1 Samuel": "1Sam",
            "2 Samuel": "2Sam",
            "1 Kings": "1Kgs",
            "2 Kings": "2Kgs",
            "1 Chronicles": "1Chr",
            "2 Chronicles": "2Chr",
            "Ezra": "Ezra",
            "Nehemiah": "Neh",
            "Esther": "Esth",
            "Job": "Job",
            "Psalms": "Ps",
            "Proverbs": "Prov",
            "Ecclesiastes": "Eccl",
            "Song of Solomon": "Song",
            "Isaiah": "Isa",
            "Jeremiah": "Jer",
            "Lamentations": "Lam",
            "Ezekiel": "Ezek",
            "Daniel": "Dan",
            "Hosea": "Hos",
            "Joel": "Joel",
            "Amos": "Amos",
            "Obadiah": "Obad",
            "Jonah": "Jonah",
            "Micah": "Mic",
            "Nahum": "Nah",
            "Habakkuk": "Hab",
            "Zephaniah": "Zeph",
            "Haggai": "Hag",
            "Zechariah": "Zech",
            "Malachi": "Mal",
            "Matthew": "Matt",
            "Mark": "Mark",
            "Luke": "Luke",
            "John": "John",
            "Acts": "Acts",
            "Romans": "Rom",
            "1 Corinthians": "1Cor",
            "2 Corinthians": "2Cor",
            "Galatians": "Gal",
            "Ephesians": "Eph",
            "Philippians": "Phil",
            "Colossians": "Col",
            "1 Thessalonians": "1Thess",
            "2 Thessalonians": "2Thess",
            "1 Timothy": "1Tim",
            "2 Timothy": "2Tim",
            "Titus": "Titus",
            "Philemon": "Phlm",
            "Hebrews": "Heb",
            "James": "Jas",
            "1 Peter": "1Pet",
            "2 Peter": "2Pet",
            "1 John": "1John",
            "2 John": "2John",
            "3 John": "3John",
            "Jude": "Jude",
            "Revelation": "Rev"
        ]
        
        return bookMappings[fullName] ?? fullName
    }
    
    func getFullBookName(from abbreviation: String) -> String {
        let reverseMappings: [String: String] = [
            "Gen": "Genesis",
            "Exod": "Exodus",
            "Lev": "Leviticus",
            "Num": "Numbers",
            "Deut": "Deuteronomy",
            "Josh": "Joshua",
            "Judg": "Judges",
            "Ruth": "Ruth",
            "1Sam": "1 Samuel",
            "2Sam": "2 Samuel",
            "1Kgs": "1 Kings",
            "2Kgs": "2 Kings",
            "1Chr": "1 Chronicles",
            "2Chr": "2 Chronicles",
            "Ezra": "Ezra",
            "Neh": "Nehemiah",
            "Esth": "Esther",
            "Job": "Job",
            "Ps": "Psalms",
            "Prov": "Proverbs",
            "Eccl": "Ecclesiastes",
            "Song": "Song of Solomon",
            "Isa": "Isaiah",
            "Jer": "Jeremiah",
            "Lam": "Lamentations",
            "Ezek": "Ezekiel",
            "Dan": "Daniel",
            "Hos": "Hosea",
            "Joel": "Joel",
            "Amos": "Amos",
            "Obad": "Obadiah",
            "Jonah": "Jonah",
            "Mic": "Micah",
            "Nah": "Nahum",
            "Hab": "Habakkuk",
            "Zeph": "Zephaniah",
            "Hag": "Haggai",
            "Zech": "Zechariah",
            "Mal": "Malachi",
            "Matt": "Matthew",
            "Mark": "Mark",
            "Luke": "Luke",
            "John": "John",
            "Acts": "Acts",
            "Rom": "Romans",
            "1Cor": "1 Corinthians",
            "2Cor": "2 Corinthians",
            "Gal": "Galatians",
            "Eph": "Ephesians",
            "Phil": "Philippians",
            "Col": "Colossians",
            "1Thess": "1 Thessalonians",
            "2Thess": "2 Thessalonians",
            "1Tim": "1 Timothy",
            "2Tim": "2 Timothy",
            "Titus": "Titus",
            "Phlm": "Philemon",
            "Heb": "Hebrews",
            "Jas": "James",
            "1Pet": "1 Peter",
            "2Pet": "2 Peter",
            "1John": "1 John",
            "2John": "2 John",
            "3John": "3 John",
            "Jude": "Jude",
            "Rev": "Revelation"
        ]
        
        return reverseMappings[abbreviation] ?? abbreviation
    }
}
