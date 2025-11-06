import SwiftUI
import Supabase

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var bibleRouter: BibleRouter
    @AppStorage("lastBookId") private var lastBookId: Int = 0
    @AppStorage("lastBookName") private var lastBookName: String = ""
    @AppStorage("lastChapter") private var lastChapter: Int = 0
    @State private var authError: String?
    @State private var showProfile: Bool = false
    @ObservedObject private var streak = StreakService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search (moved to top)
                    SectionHeader(title: "Search")
                    HStack(spacing: 8) {
                        NavigationLink(destination: SearchView()) {
                            CardRow(iconSystemName: "magnifyingglass", title: "Search Scripture")
                        }
                        .buttonStyle(.plain)

                        StreakBadge(count: streak.streakCount)
                    }

                    // Verse of the Day
                    VerseOfTheDayCard()

                    // Continue to last chapter if available; otherwise open books list
                    Button(action: {
                        if lastBookId > 0 && lastChapter > 0 {
                            Task {
                                if let books = try? await BibleService.shared.fetchBooks(),
                                   let actualBook = books.first(where: { $0.id == lastBookId }) {
                                    bibleRouter.goToChapter(book: actualBook, chapter: lastChapter)
                                } else {
                                    // Fallback with correct chapter count for Joshua
                                    let book = BibleBook(id: lastBookId, name: lastBookName, abbreviation: "", testament: nil, chapters: getChapterCount(for: lastBookName))
                                    bibleRouter.goToChapter(book: book, chapter: lastChapter)
                                }
                            }
                        } else {
                            bibleRouter.goToBooksRoot()
                        }
                    }) {
                        CardRow(iconSystemName: "book", title: lastBookId > 0 ? "Continue — \(lastBookName) \(lastChapter)" : "Open the Bible", subtitle: lastBookId > 0 ? "Jump back to where you left off" : nil)
                    }
                    .buttonStyle(.plain)

                    // Bookmarks & Notes
                    NavigationLink(destination: BookmarksNotesView()) {
                        CardRow(iconSystemName: "bookmark", title: "Bookmarks & Notes", subtitle: "Your saved verses and notes")
                    }
                    .buttonStyle(.plain)

                    // Reading Tracker (with progress barometer inline)
                    NavigationLink(destination: ReadingTrackerView()) {
                        ReadingProgressRow(iconSystemName: "checkmark.circle", title: "Holy Roll Call")
                    }
                    .buttonStyle(.plain)

                    // Cross References visualization shortcut
                    NavigationLink(destination: CrossReferencesView(focusId: nil)) {
                        CardRow(iconSystemName: "link", title: "Cross References", subtitle: "Visualize verse connections")
                    }

                // Feedback prominent shortcut on Home
                NavigationLink(destination: FeedbackView()) {
                    CardRow(iconSystemName: "ladybug.fill", title: "Send Feedback", subtitle: "Report a flaw or suggest improvements")
                }
                    .buttonStyle(.plain)

                    if !auth.isSignedIn {
                        SectionHeader(title: "Account")
                        NavigationLink(destination: SignInView()) {
                            CardRow(iconSystemName: "person.crop.circle.badge.plus", title: "Sign in", subtitle: "Sync bookmarks across devices")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            // No tab bar hide/show on Home; keep it stable here
            .toolbar(.hidden, for: .navigationBar)
            // Removed forced sign-in screen; users can continue as guests
            // OAuth callback is handled globally at the app root
            .overlay(alignment: .bottom) {
                if let authError {
                    Text(authError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(8)
                }
            }
        }
        .task { _ = StreakService.shared.updateIfNeeded() }
    }

    @ViewBuilder
    private func bibleDestination() -> some View {
        if lastBookId > 0 && lastChapter > 0 {
            let book = BibleBook(id: lastBookId, name: lastBookName, abbreviation: "", testament: nil, chapters: getChapterCount(for: lastBookName))
            VersesView(book: book, chapter: lastChapter)
        } else {
            BookListView()
        }
    }

    private func getChapterCount(for bookName: String) -> Int {
        // Return the correct number of chapters for each book
        let chapterCounts: [String: Int] = [
            "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
            "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
            "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36,
            "Ezra": 10, "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150,
            "Proverbs": 31, "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66,
            "Jeremiah": 52, "Lamentations": 5, "Ezekiel": 48, "Daniel": 12,
            "Hosea": 14, "Joel": 3, "Amos": 9, "Obadiah": 1, "Jonah": 4,
            "Micah": 7, "Nahum": 3, "Habakkuk": 3, "Zephaniah": 3,
            "Haggai": 2, "Zechariah": 14, "Malachi": 4, "Matthew": 28,
            "Mark": 16, "Luke": 24, "John": 21, "Acts": 28, "Romans": 16,
            "1 Corinthians": 16, "2 Corinthians": 13, "Galatians": 6, "Ephesians": 6,
            "Philippians": 4, "Colossians": 4, "1 Thessalonians": 5, "2 Thessalonians": 3,
            "1 Timothy": 6, "2 Timothy": 4, "Titus": 3, "Philemon": 1,
            "Hebrews": 13, "James": 5, "1 Peter": 5, "2 Peter": 3, "1 John": 5,
            "2 John": 1, "3 John": 1, "Jude": 1, "Revelation": 22
        ]
        return chapterCounts[bookName] ?? 150 // Default fallback
    }
}

// MARK: - Auth actions
extension HomeView {
    private func signInWithGoogle() {
        Task {
            do {
                let redirect = URL(string: "bibleapp://auth-callback")!
                _ = try await SupabaseManager.shared.client.auth.signInWithOAuth(
                    provider: .google,
                    redirectTo: redirect
                )
            } catch {
                authError = error.localizedDescription
            }
        }
    }
}

// MARK: - Profile toolbar
extension HomeView {
    @ToolbarContentBuilder
    func profileToolbarItem() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showProfile = true }) {
                Image(systemName: "person")
                    .symbolVariant(.none)
                    .font(.system(size: 22, weight: .semibold))
            }
            .buttonStyle(IconFillOnPressStyle())
        }
    }
}

// MARK: - Reusable views
private struct CardRow: View {
    let iconSystemName: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                Image(systemName: iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }
}

// A button style that switches to the filled SF Symbol variant while pressed
private struct IconFillOnPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .symbolVariant(configuration.isPressed ? .fill : .none)
    }
}

// Removed placeholder; replaced with functional SearchView in SearchView.swift

private struct VerseOfTheDayCard: View {
    @State private var votd: VerseOfTheDay? = nil
    @State private var isLoading: Bool = true
    @EnvironmentObject private var bibleRouter: BibleRouter

    var body: some View {
        Button(action: {
            guard let votd = votd else { return }
            navigateToVerse(reference: votd.reference)
        }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Verse of the Day")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let votd {
                    Text(votd.text)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("– \(votd.reference)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if isLoading {
                    ProgressView().tint(.secondary)
                } else {
                    Text("Unable to load verse.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(votd != nil ? "Verse of the Day: \(votd!.text) — \(votd!.reference)" : "Verse of the Day loading")
        .task {
            isLoading = true
            let result = await VerseOfTheDayService.shared.getToday()
            self.votd = result
            isLoading = false
        }
        .contextMenu {
            Button {
                Task {
                    isLoading = true
                    VerseOfTheDayService.shared.restartAtToday()
                    self.votd = await VerseOfTheDayService.shared.getToday()
                    isLoading = false
                }
            } label: { Label("Restart at Day 1 Today", systemImage: "arrow.clockwise") }
            Button {
                Task {
                    isLoading = true
                    self.votd = await VerseOfTheDayService.shared.getToday()
                    isLoading = false
                }
            } label: { Label("Refresh Verse", systemImage: "gobackward") }
        }
    }
    
    private func navigateToVerse(reference: String) {
        Task {
            print("📖 Navigating to verse: '\(reference)'")
            
            // Parse reference like "Psalm 27:1" to extract book name, chapter, and verse
            let components = reference.split(separator: " ")
            guard components.count >= 2 else { 
                print("❌ Not enough components in reference")
                return 
            }
            
            print("📝 Components: \(components)")
            
            // Handle book names with multiple words (e.g., "1 Corinthians", "Song of Solomon")
            var bookName = ""
            var chapterVerseString = ""
            
            // Find the last component that contains a colon (verse reference)
            if let lastIndex = components.lastIndex(where: { $0.contains(":") }) {
                chapterVerseString = String(components[lastIndex])
                bookName = components[..<lastIndex].joined(separator: " ")
            } else if let lastIndex = components.lastIndex(where: { $0.allSatisfy { $0.isNumber } }) {
                // If no colon, the last number is the chapter
                chapterVerseString = String(components[lastIndex])
                bookName = components[..<lastIndex].joined(separator: " ")
            } else {
                print("❌ Could not find chapter:verse pattern")
                return
            }
            
            print("📚 Book name: '\(bookName)'")
            print("🔢 Chapter:Verse string: '\(chapterVerseString)'")
            
            // Extract chapter and verse numbers
            let chapterVerseParts = chapterVerseString.split(separator: ":")
            guard let chapter = Int(chapterVerseParts.first ?? "") else { 
                print("❌ Could not parse chapter number")
                return 
            }
            let verse = chapterVerseParts.count > 1 ? Int(chapterVerseParts[1]) : nil
            
            print("📖 Parsed - Book: '\(bookName)', Chapter: \(chapter), Verse: \(verse ?? 0)")
            
            // Fetch books and find the matching book
            do {
                let books = try await BibleService.shared.fetchBooks()
                print("📚 Available books: \(books.map { $0.name })")
                
                // Try exact match first
                if let book = books.first(where: { $0.name.lowercased() == bookName.lowercased() }) {
                    print("✅ Found exact match: \(book.name)")
                    if let verse = verse {
                        print("🎯 Navigating to verse: \(book.name) \(chapter):\(verse)")
                        bibleRouter.goToVerse(book: book, chapter: chapter, verse: verse)
                    } else {
                        print("🎯 Navigating to chapter: \(book.name) \(chapter)")
                        bibleRouter.goToChapter(book: book, chapter: chapter)
                    }
                    return
                }
                
                // Try partial match (for books like "Psalms" vs "Psalm")
                if let book = books.first(where: { 
                    $0.name.lowercased().contains(bookName.lowercased()) || 
                    bookName.lowercased().contains($0.name.lowercased())
                }) {
                    print("✅ Found partial match: \(book.name) for '\(bookName)'")
                    if let verse = verse {
                        print("🎯 Navigating to verse: \(book.name) \(chapter):\(verse)")
                        bibleRouter.goToVerse(book: book, chapter: chapter, verse: verse)
                    } else {
                        print("🎯 Navigating to chapter: \(book.name) \(chapter)")
                        bibleRouter.goToChapter(book: book, chapter: chapter)
                    }
                    return
                }
                
                print("❌ No matching book found for '\(bookName)'")
            } catch {
                print("❌ Error fetching books: \(error)")
            }
        }
    }
}

private struct ReadingProgressCard: View {
    @ObservedObject private var tracker = ReadingTrackerService.shared
    @State private var totalBooks: Int = 66

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Books read: \(tracker.readBookIds.count)/\(totalBooks)")
                .font(.headline)
                .foregroundColor(.primary)
            ProgressView(value: Double(tracker.readBookIds.count), total: Double(totalBooks))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .task {
            if let list = try? await BibleService.shared.fetchBooks() {
                totalBooks = list.count
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading progress: \(tracker.readBookIds.count) of \(totalBooks) books read")
    }
}

private struct StreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("👑")
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak \(count) days")
    }
}

private struct ReadingProgressRow: View {
    let iconSystemName: String
    let title: String
    @ObservedObject private var tracker = ReadingTrackerService.shared
    @State private var totalBooks: Int = 66

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                Image(systemName: iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Books read: \(tracker.readBookIds.count)/\(totalBooks)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView(value: Double(tracker.readBookIds.count), total: Double(totalBooks))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .task {
            if let list = try? await BibleService.shared.fetchBooks() {
                totalBooks = list.count
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Holy Roll Call progress: \(tracker.readBookIds.count) of \(totalBooks) books read")
    }
}

