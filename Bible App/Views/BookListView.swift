import SwiftUI

struct BookListView: View {
    @State private var books: [BibleBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedBookIds: Set<Int> = []
    @State private var navTarget: ChapterTarget?
    @EnvironmentObject private var bibleRouter: BibleRouter
    @State private var chapterPickerBook: BibleBook? = nil
    @State private var showValidation: Bool = false
    @State private var isOldExpanded: Bool = true
    @State private var isNewExpanded: Bool = true
    @State private var showSearch: Bool = false


    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundColor(.red) }

            DisclosureGroup(isExpanded: $isOldExpanded) {
                ForEach(sortedBooks(oldTestamentBooks(books))) { book in
                    bookRow(book)
                }
            } label: {
                Text("Old Testament")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }

            DisclosureGroup(isExpanded: $isNewExpanded) {
                ForEach(sortedBooks(newTestamentBooks(books))) { book in
                    bookRow(book)
                }
            } label: {
                Text("New Testament")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
        }
        .navigationTitle("Books")
        // Navigation handled by BibleRouter via MainTabsView
        .task { await load() }
        .overlay { if isLoading { ProgressView() } }
        .onReceive(NotificationCenter.default.publisher(for: .closeAllBooks)) { _ in
            expandedBookIds.removeAll()
        }
        .sheet(item: $chapterPickerBook) { book in
            ChapterPicker(book: book) { chapter in
                bibleRouter.goToChapter(book: book, chapter: chapter)
                chapterPickerBook = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showValidation = true }) { Image(systemName: "checklist") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSearch = true }) { Image(systemName: "magnifyingglass") }
            }
        }
        .sheet(isPresented: $showValidation) {
            NavigationStack { ValidationReportView() }
        }
        .sheet(isPresented: $showSearch) {
            NavigationStack { SearchView() }
        }
    }

    private func sortedBooks(_ list: [BibleBook]) -> [BibleBook] {
        // Filter out any invalid book entries
        let validBooks = list.filter { book in
            !book.name.isEmpty && book.name != "cancelled" && book.id > 0
        }

        return validBooks.sorted { a, b in
            let ai = BibleService.shared.canonicalOrderIndex(for: a.name)
            let bi = BibleService.shared.canonicalOrderIndex(for: b.name)
            if ai != bi { return ai < bi }
            return a.id < b.id
        }
    }

    private func displayName(for book: BibleBook) -> String {
        if book.id == 22 { return "Song of Solomon" }
        return book.name
    }

    private func bookRow(_ book: BibleBook) -> some View {
        let isActive = chapterPickerBook?.id == book.id
        return Button(action: {
            if chapterPickerBook?.id == book.id {
                chapterPickerBook = nil
            } else {
                chapterPickerBook = book
            }
        }) {
            HStack {
                if #available(iOS 17.0, *) {
                    Text(displayName(for: book))
                        .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .contentTransition(.interpolate)
                        .animation(.easeInOut(duration: 0.25), value: isActive)
                } else {
                    Text(displayName(for: book))
                        .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(isActive ? 90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isActive)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 64)
            .background(Color(.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func oldTestamentBooks(_ list: [BibleBook]) -> [BibleBook] {
        let valid = list.filter { $0.id > 0 }
        let ot = valid.filter { book in
            if let t = book.testament?.lowercased() { return t.contains("old") || t == "ot" }
            return book.id <= 39
        }
        return ot
    }

    private func newTestamentBooks(_ list: [BibleBook]) -> [BibleBook] {
        let valid = list.filter { $0.id > 0 }
        let nt = valid.filter { book in
            if let t = book.testament?.lowercased() { return t.contains("new") || t == "nt" }
            return book.id >= 40
        }
        return nt
    }

    

    private func load() async {
        do {
            let fetchedBooks = try await BibleService.shared.fetchBooks()
            await MainActor.run {
                books = fetchedBooks
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

private struct ChapterTarget: Identifiable, Hashable {
    let book: BibleBook
    let chapter: Int
    var id: String { "\(book.id)-\(chapter)" }

    static func == (lhs: ChapterTarget, rhs: ChapterTarget) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct ChapterPicker: View {
    let book: BibleBook
    let onPick: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(1...book.chapters, id: \.self) { chapter in
                        Button(action: { onPick(chapter) }) {
                            Text("\(chapter)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color(.tertiarySystemFill))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle(book.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// closeAllBooks moved to Models/Notifications.swift
