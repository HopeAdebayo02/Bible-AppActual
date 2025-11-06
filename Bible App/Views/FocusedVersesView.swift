import SwiftUI
import UIKit

struct FocusedVersesView: View {
    let bookId: Int
    let bookName: String
    let chapter: Int
    let verses: [Int]
    let note: String?

    @State private var content: [BibleVerse] = []
    @State private var isLoading = true
    @State private var goToChapter: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink(value: "\(bookId)-\(chapter)") { EmptyView() }

                if let note, !note.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note").font(.caption).foregroundColor(.secondary)
                            Text(note)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Verses").font(.caption).foregroundColor(.secondary)
                        ForEach(content) { v in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(v.verse)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .baselineOffset(6)
                                Text(v.text)
                                    .font(.system(size: 20, weight: .regular, design: .serif))
                                    .foregroundColor(.primary)
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .contextMenu {
                                Button { shareSingle(v) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                                Button { UIPasteboard.general.string = combinedText([v]); } label: { Label("Copy", systemImage: "doc.on.doc") }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { shareAll() }) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .task { await load() }
        .navigationDestination(for: String.self) { _ in
            VersesView(book: BibleBook(id: bookId, name: bookName, abbreviation: "", testament: nil, chapters: 150), chapter: chapter)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: { goToChapter = true }) {
                        HStack(spacing: 8) {
                            Text("\(bookName) \(chapter)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let first = content.first {
                                Text("|")
                                    .foregroundColor(.secondary)
                                Text(first.version)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider()
            }
            .background(Color(.systemBackground))
        }
    }

    private func load() async {
        do {
            let all = try await BibleService.shared.fetchVerses(bookId: bookId, chapter: chapter)
            let set = Set(verses)
            let filtered = all.filter { set.contains($0.verse) }.sorted { $0.verse < $1.verse }
            await MainActor.run {
                content = filtered
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func combinedText(_ list: [BibleVerse]) -> String {
        list.map { "\(bookName) \(chapter):\($0.verse) — \($0.text)" }.joined(separator: "\n\n")
    }

    private func shareAll() {
        let items: [Any] = [combinedText(content) + (note.map { "\n\nNote: \($0)" } ?? "")]
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        presentActivityController(av)
    }

    private func shareSingle(_ v: BibleVerse) {
        let av = UIActivityViewController(activityItems: [combinedText([v])], applicationActivities: nil)
        presentActivityController(av)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

// MARK: - UIKit helpers (shared)
private func topMostController() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }),
          let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
    var current: UIViewController? = root
    while let presented = current?.presentedViewController { current = presented }
    return current
}

private func presentActivityController(_ av: UIActivityViewController) {
    topMostController()?.present(av, animated: true)
}
