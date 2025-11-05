import SwiftUI

struct MainTabsView: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("lastBookId") private var lastBookId: Int = 0
    @AppStorage("lastBookName") private var lastBookName: String = ""
    @AppStorage("lastChapter") private var lastChapter: Int = 0
    @State private var selected: Int = 0
    @State private var bibleNavigationPath = NavigationPath()
    @StateObject private var bibleRouter = BibleRouter()

    struct BibleDestination: Hashable {
        let book: BibleBook
        let chapter: Int
        let targetVerse: Int?
        
        init(book: BibleBook, chapter: Int, targetVerse: Int? = nil) {
            self.book = book
            self.chapter = chapter
            self.targetVerse = targetVerse
        }
    }

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack { HomeView() }
                .tabItem { tabLabel(outline: "house", filled: "house.fill", title: "Home", index: 0) }
                .tag(0)

            NavigationStack(path: $bibleNavigationPath) {
                bibleRoot()
                    .navigationDestination(for: BibleDestination.self) { destination in
                        VersesView(book: destination.book, chapter: destination.chapter, targetVerse: destination.targetVerse)
                    }
            }
            .tabItem { tabLabel(outline: "book", filled: "book.fill", title: "Bible", index: 1) }
            .tag(1)

            NavigationStack { ProfileSheetView() }
                .tabItem { tabLabel(outline: "person", filled: "person.fill", title: "Profile", index: 2) }
                .tag(2)

            NavigationStack { FeedbackView() }
                .tabItem { tabLabel(outline: "ladybug", filled: "ladybug.fill", title: "Feedback", index: 3) }
                .tag(3)
        }
        .environmentObject(bibleRouter)
        .onReceive(NotificationCenter.default.publisher(for: .openBibleTab)) { _ in
            selected = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBooksList)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selected = 1
            }
            // Give SwiftUI a moment to switch tabs before clearing the path
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                bibleNavigationPath = NavigationPath()
            }
        }
        .onReceive(bibleRouter.$lastCommandId) { _ in
            guard let cmd = bibleRouter.lastCommand else { return }
            switch cmd {
            case .goToBooksRoot:
                selected = 1
                DispatchQueue.main.async {
                    bibleNavigationPath = NavigationPath()
                }
            case .goToChapter(let book, let chapter):
                selected = 1
                DispatchQueue.main.async {
                    bibleNavigationPath = NavigationPath()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let dest = BibleDestination(book: book, chapter: chapter)
                    bibleNavigationPath.append(dest)
                }
            case .goToVerse(let book, let chapter, let verse):
                selected = 1
                DispatchQueue.main.async {
                    bibleNavigationPath = NavigationPath()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let dest = BibleDestination(book: book, chapter: chapter, targetVerse: verse)
                    bibleNavigationPath.append(dest)
                }
            }
        }
    }

    @ViewBuilder
    private func bibleRoot() -> some View {
        BookListView()
    }

    @ViewBuilder
    private func tabLabel(outline: String, filled: String, title: String, index: Int) -> some View {
        let isSelected = selected == index
        Image(systemName: isSelected ? filled : outline)
        Text(title)
    }
}


