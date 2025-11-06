import SwiftUI

struct SplitStudyView: View {
    let initialBook: BibleBook
    let initialChapter: Int

    @Environment(\.dismiss) private var dismiss
    @State private var books: [BibleBook] = []

    @State private var leftBook: BibleBook
    @State private var leftChapter: Int
    @State private var rightBook: BibleBook
    @State private var rightChapter: Int

    @State private var showLeftPicker: Bool = false
    @State private var showRightPicker: Bool = false

    init(initialBook: BibleBook, initialChapter: Int) {
        self.initialBook = initialBook
        self.initialChapter = initialChapter
        _leftBook = State(initialValue: initialBook)
        _leftChapter = State(initialValue: initialChapter)
        _rightBook = State(initialValue: initialBook)
        _rightChapter = State(initialValue: initialChapter)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 1) {
                SplitPane(title: "Left", book: $leftBook, chapter: $leftChapter, books: books, showPicker: $showLeftPicker)
                Divider()
                SplitPane(title: "Right", book: $rightBook, chapter: $rightChapter, books: books, showPicker: $showRightPicker)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Study Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { await loadBooksIfNeeded() }
            .sheet(isPresented: $showLeftPicker) {
                SplitChapterPicker(book: $leftBook, chapter: $leftChapter, books: books)
            }
            .sheet(isPresented: $showRightPicker) {
                SplitChapterPicker(book: $rightBook, chapter: $rightChapter, books: books)
            }
        }
    }

    private func loadBooksIfNeeded() async {
        guard books.isEmpty else { return }
        do { books = try await BibleService.shared.fetchBooks() } catch { }
    }
}

private struct SplitPane: View {
    let title: String
    @Binding var book: BibleBook
    @Binding var chapter: Int
    let books: [BibleBook]
    @Binding var showPicker: Bool

    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { showPicker = true }) {
                    HStack(spacing: 6) {
                        Text("\(book.name) \(chapter)")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button(action: goPrev) {
                    Image(systemName: "chevron.left")
                }.disabled(!canGoPrev())

                Button(action: goNext) {
                    Image(systemName: "chevron.right")
                }.disabled(!canGoNext())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(verses) { v in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(v.verse)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .baselineOffset(6)
                            Text(v.text)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundColor(.primary)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
            }
        }
        .task(id: book.id) { await load() }
        .task(id: chapter) { await load() }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedVerses = try await BibleService.shared.fetchVerses(bookId: book.id, chapter: chapter)
            await MainActor.run {
                verses = fetchedVerses
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func goNext() {
        if chapter < book.chapters { chapter += 1; return }
        if let idx = books.firstIndex(where: { $0.id == book.id }), idx < books.count - 1 {
            book = books[idx + 1]
            chapter = 1
        }
    }
    private func goPrev() {
        if chapter > 1 { chapter -= 1; return }
        if let idx = books.firstIndex(where: { $0.id == book.id }), idx > 0 {
            let prev = books[idx - 1]
            book = prev
            chapter = prev.chapters
        }
    }
    private func canGoNext() -> Bool {
        if let idx = books.firstIndex(where: { $0.id == book.id }), idx == books.count - 1 {
            return chapter < book.chapters
        }
        return true
    }
    private func canGoPrev() -> Bool {
        if let idx = books.firstIndex(where: { $0.id == book.id }), idx == 0 {
            return chapter > 1
        }
        return true
    }
}

private struct SplitChapterPicker: View {
    @Binding var book: BibleBook
    @Binding var chapter: Int
    let books: [BibleBook]

    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { b in
                    Section(header: Text(b.name)) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                            ForEach(1...b.chapters, id: \.self) { c in
                                Button(action: { book = b; chapter = c; dismissSheet() }) {
                                    Text("\(c)")
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Choose Chapter")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func dismissSheet() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


