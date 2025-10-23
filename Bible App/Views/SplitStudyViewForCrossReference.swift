import SwiftUI

struct SplitStudyViewForCrossReference: View {
    let originalVerse: BibleVerse
    let originalBookName: String
    let crossRef: CrossReference
    
    @Environment(\.dismiss) private var dismiss
    @State private var leftBook: BibleBook
    @State private var rightBook: BibleBook
    @State private var leftChapter: Int
    @State private var rightChapter: Int
    @State private var leftTranslation: String = "BSB"
    @State private var rightTranslation: String = "BSB"
    @State private var showLeftTranslationPicker = false
    @State private var showRightTranslationPicker = false
    @State private var showAddToCrossRefMap = false
    @State private var showCrossRefMap = false
    @State private var savedCrossRefId: UUID?
    
    init(originalVerse: BibleVerse, originalBookName: String, crossRef: CrossReference) {
        print("🔄 Initializing SplitStudyViewForCrossReference")
        print("📖 Original: \(originalBookName) \(originalVerse.chapter):\(originalVerse.verse)")
        print("🔗 Cross-ref: \(crossRef.displayText)")
        
        self.originalVerse = originalVerse
        self.originalBookName = originalBookName
        self.crossRef = crossRef
        
        // Initialize left side with original verse
        self._leftBook = State(initialValue: BibleBook(
            id: originalVerse.book_id,
            name: originalBookName,
            abbreviation: "",
            testament: nil,
            chapters: 150
        ))
        self._leftChapter = State(initialValue: originalVerse.chapter)
        
        // Initialize right side with cross-reference
        let targetBookName = CrossReferenceService.shared.getFullBookName(from: crossRef.toBook)
        // Use a reasonable book ID based on the book name
        let targetBookId = Self.getBookIdFromName(targetBookName)
        self._rightBook = State(initialValue: BibleBook(
            id: targetBookId,
            name: targetBookName,
            abbreviation: crossRef.toBook,
            testament: nil,
            chapters: 150
        ))
        self._rightChapter = State(initialValue: crossRef.toChapter)
    }
    
    // Helper function to get approximate book ID from name
    private static func getBookIdFromName(_ bookName: String) -> Int {
        let bookIds: [String: Int] = [
            "Genesis": 1, "Exodus": 2, "Leviticus": 3, "Numbers": 4, "Deuteronomy": 5,
            "Joshua": 6, "Judges": 7, "Ruth": 8, "1 Samuel": 9, "2 Samuel": 10,
            "1 Kings": 11, "2 Kings": 12, "1 Chronicles": 13, "2 Chronicles": 14,
            "Ezra": 15, "Nehemiah": 16, "Esther": 17, "Job": 18, "Psalms": 19,
            "Proverbs": 20, "Ecclesiastes": 21, "Song of Solomon": 22, "Isaiah": 23,
            "Jeremiah": 24, "Lamentations": 25, "Ezekiel": 26, "Daniel": 27,
            "Hosea": 28, "Joel": 29, "Amos": 30, "Obadiah": 31, "Jonah": 32,
            "Micah": 33, "Nahum": 34, "Habakkuk": 35, "Zephaniah": 36, "Haggai": 37,
            "Zechariah": 38, "Malachi": 39, "Matthew": 40, "Mark": 41, "Luke": 42,
            "John": 43, "Acts": 44, "Romans": 45, "1 Corinthians": 46, "2 Corinthians": 47,
            "Galatians": 48, "Ephesians": 49, "Philippians": 50, "Colossians": 51,
            "1 Thessalonians": 52, "2 Thessalonians": 53, "1 Timothy": 54, "2 Timothy": 55,
            "Titus": 56, "Philemon": 57, "Hebrews": 58, "James": 59, "1 Peter": 60,
            "2 Peter": 61, "1 John": 62, "2 John": 63, "3 John": 64, "Jude": 65,
            "Revelation": 66
        ]
        return bookIds[bookName] ?? 1
    }
    
    var body: some View {
        let _ = print("🎨 Rendering SplitStudyViewForCrossReference body")
        
        return NavigationStack {
            HStack(spacing: 0) {
            // Left side - Original verse
            VStack(spacing: 0) {
                // Left header
                VStack(spacing: 4) {
                    HStack {
                        Text("\(leftBook.name) \(leftChapter)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: { showLeftTranslationPicker = true }) {
                            HStack(spacing: 4) {
                                Text(leftTranslation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Left content
                SplitStudyChapterView(
                    book: leftBook,
                    chapter: leftChapter,
                    focusVerse: originalVerse.verse,
                    translation: leftTranslation
                )
            }
            
            // Divider
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
            
            // Right side - Cross-reference
            VStack(spacing: 0) {
                // Right header
                VStack(spacing: 4) {
                    HStack {
                        Text(crossRef.displayText)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: { showRightTranslationPicker = true }) {
                            HStack(spacing: 4) {
                                Text(rightTranslation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground))
                            .cornerRadius(6)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Right content
                SplitStudyChapterView(
                    book: rightBook,
                    chapter: rightChapter,
                    focusVerse: crossRef.toVerseNumber,
                    focusEndVerse: crossRef.toVerseEndNumber,
                    translation: rightTranslation
                )
            }
            }
            .navigationTitle("Cross Reference Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddToCrossRefMap = true }) {
                        Image(systemName: "link.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showLeftTranslationPicker) {
                CrossRefTranslationPicker(selectedTranslation: $leftTranslation)
            }
            .sheet(isPresented: $showRightTranslationPicker) {
                CrossRefTranslationPicker(selectedTranslation: $rightTranslation)
            }
            .sheet(isPresented: $showAddToCrossRefMap) {
                CrossRefMapAddSheet(
                    sourceBookId: originalVerse.book_id,
                    sourceBookName: originalBookName,
                    sourceChapter: originalVerse.chapter,
                    sourceVerse: originalVerse.verse,
                    targetBookId: rightBook.id,
                    targetBookName: rightBook.name,
                    targetChapter: rightChapter,
                    targetVerse: crossRef.toVerseNumber,
                    onSaved: { crossRefId in
                        showAddToCrossRefMap = false
                        savedCrossRefId = crossRefId
                        showCrossRefMap = true
                    }
                )
            }
            .sheet(isPresented: $showCrossRefMap) {
                CrossRefMapModal(focusId: savedCrossRefId)
            }
            .onAppear {
                print("✅ SplitStudyView appeared - forcing render")
                // Force a layout pass to ensure rendering
                DispatchQueue.main.async {
                    print("🔄 Layout pass triggered")
                }
            }
        }
    }
}

struct SplitStudyChapterView: View {
    let book: BibleBook
    let chapter: Int
    let focusVerse: Int
    let focusEndVerse: Int?
    let translation: String
    
    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true
    @State private var items: [ChapterItem] = []
    @State private var errorMessage: String?
    
    init(book: BibleBook, chapter: Int, focusVerse: Int, focusEndVerse: Int? = nil, translation: String = "BSB") {
        self.book = book
        self.chapter = chapter
        self.focusVerse = focusVerse
        self.focusEndVerse = focusEndVerse
        self.translation = translation
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            List(items, id: \.id) { item in
                Group {
                    switch item {
                    case .heading(let text, _):
                        Text(text)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    case .verse(let verse):
                        verseRow(verse: verse)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .overlay {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading \(book.name) \(chapter)...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error Loading Chapter")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Text("Book: \(book.name) (ID: \(book.id)), Chapter: \(chapter)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Verses Found")
                            .font(.headline)
                        Text("Book: \(book.name) (ID: \(book.id)), Chapter: \(chapter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .task {
                await loadVerses()
            }
            .onAppear {
                scrollToFocusVerse(proxy: proxy)
            }
            .onChange(of: items.count) { _ in
                scrollToFocusVerse(proxy: proxy)
            }
            .onChange(of: translation) { _, _ in
                Task {
                    await loadVerses()
                }
            }
        }
    }
    
    @ViewBuilder
    private func verseRow(verse: BibleVerse) -> some View {
        let isFocused = verse.verse >= focusVerse && verse.verse <= (focusEndVerse ?? focusVerse)
        
        HStack(alignment: .top, spacing: 6) {
            Text("\(verse.verse)")
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            Text(verse.text)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 6)
        .background(isFocused ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .id("verse-\(verse.verse)")
    }
    
    private func loadVerses() async {
        isLoading = true
        errorMessage = nil
        
        print("Loading verses for \(book.name) (ID: \(book.id)), Chapter: \(chapter), Translation: \(translation)")
        
        do {
            verses = try await BibleService.shared.fetchVerses(bookId: book.id, chapter: chapter, version: translation)
            print("Loaded \(verses.count) verses for \(book.name) \(chapter) (\(translation))")
            
            if verses.isEmpty {
                errorMessage = "No verses found for \(book.name) chapter \(chapter)"
            } else {
                items = ChapterItem.build(from: verses)
                print("Built \(items.count) chapter items")
            }
        } catch {
            print("Failed to load verses for \(book.name) \(chapter): \(error)")
            errorMessage = "Failed to load verses: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func scrollToFocusVerse(proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo("verse-\(focusVerse)", anchor: .center)
            }
        }
    }
}

// MARK: - Translation Picker Sheet
private struct CrossRefTranslationPicker: View {
    @Binding var selectedTranslation: String
    @Environment(\.dismiss) private var dismiss
    
    private let availableTranslations = TranslationService.shared.available
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(availableTranslations, id: \.self) { translation in
                    Button(action: {
                        selectedTranslation = translation
                        dismiss()
                    }) {
                        HStack {
                            Text(translation)
                                .foregroundColor(.primary)
                            Spacer()
                            if translation == selectedTranslation {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add to Cross Reference Map Sheet
private struct CrossRefMapAddSheet: View {
    let sourceBookId: Int
    let sourceBookName: String
    let sourceChapter: Int
    let sourceVerse: Int
    let targetBookId: Int
    let targetBookName: String
    let targetChapter: Int
    let targetVerse: Int
    let onSaved: (UUID) -> Void
    
    @State private var isSaving = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Add Cross Reference")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("From:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(sourceBookName) \(sourceChapter):\(sourceVerse)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("To:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(targetBookName) \(targetChapter):\(targetVerse)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if showSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Cross reference added successfully!")
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: saveCrossReference) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Add to My Cross References")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isSaving || showSuccess)
            }
            .padding()
            .navigationTitle("Cross Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Don't navigate, just dismiss
                        showSuccess = false
                        isSaving = false
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }
    
    private func saveCrossReference() {
        isSaving = true
        
        // Save to LibraryService
        Task {
            do {
                // Create the cross reference using LibraryService
                let crossRefLine = CrossReferenceLine(
                    sourceBookId: sourceBookId,
                    sourceBookName: sourceBookName,
                    sourceChapter: sourceChapter,
                    sourceVerse: sourceVerse,
                    targetBookId: targetBookId,
                    targetBookName: targetBookName,
                    targetChapter: targetChapter,
                    targetVerse: targetVerse,
                    note: nil
                )
                
                LibraryService.shared.addCrossReference(crossRefLine)
                
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                    
                    // Dismiss and navigate to cross-reference map
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onSaved(crossRefLine.id)
                    }
                }
            }
        }
    }
}

#Preview {
    let sampleVerse = BibleVerse(
        id: 1,
        book_id: 1,
        chapter: 1,
        verse: 1,
        text: "In the beginning God created the heavens and the earth.",
        version: "BSB",
        heading: nil
    )
    
    let sampleCrossRef = CrossReference(
        fromVerse: "Gen.1.1",
        toVerse: "John.1.1",
        votes: 344
    )
    
    SplitStudyViewForCrossReference(
        originalVerse: sampleVerse,
        originalBookName: "Genesis",
        crossRef: sampleCrossRef
    )
}
