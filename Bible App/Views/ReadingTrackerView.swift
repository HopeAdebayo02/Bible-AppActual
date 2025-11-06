import SwiftUI

struct ReadingTrackerView: View {
    @State private var books: [BibleBook] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @ObservedObject private var tracker = ReadingTrackerService.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .navigationTitle("Holy Roll Call")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button("Mark All Old Testament") { markTestament("Old") }
                    Button("Mark All New Testament") { markTestament("New") }
                    Divider()
                    Button("Clear All", role: .destructive) { tracker.clearAll() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .task { await load() }
    }

    private var header: some View {
        let total = books.count
        let read = books.filter { tracker.isRead(bookId: $0.id) }.count
        let progress = total == 0 ? 0 : Double(read) / Double(total)
        return VStack(alignment: .leading, spacing: 8) {
            Text("You and your Bible: a page-turning relationship")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ProgressView(value: progress) {
                Text("Books read: \(read)/\(total)")
                    .font(.headline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var content: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundColor(.red) }
            ForEach(sortedBooks(books)) { book in
                HStack(spacing: 12) {
                    Image(systemName: tracker.isRead(bookId: book.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(tracker.isRead(bookId: book.id) ? .green : .secondary)
                        .font(.system(size: 20, weight: .semibold))
                    Text(book.name)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { tracker.toggle(bookId: book.id) }
            }
        }
        .overlay { if isLoading { ProgressView() } }
    }

    private func sortedBooks(_ list: [BibleBook]) -> [BibleBook] {
        list.sorted { a, b in
            let ai = BibleService.shared.canonicalOrderIndex(for: a.name)
            let bi = BibleService.shared.canonicalOrderIndex(for: b.name)
            if ai != bi { return ai < bi }
            return a.id < b.id
        }
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

    private func markTestament(_ testament: String) {
        let ids = books.filter { ($0.testament ?? "").localizedCaseInsensitiveContains(testament) }.map { $0.id }
        tracker.markAll(ids)
    }
}


