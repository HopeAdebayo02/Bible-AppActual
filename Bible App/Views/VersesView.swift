import SwiftUI
import UIKit

struct VersesView: View {
    @State private var currentBook: BibleBook
    @State private var currentChapter: Int
    @State private var allBooks: [BibleBook] = []
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bibleRouter: BibleRouter
    @ObservedObject private var library = LibraryService.shared
    @ObservedObject private var translation = TranslationService.shared
    @ObservedObject private var highlights = HighlightService.shared
    
    // Temporary highlight for navigation
    @State private var temporaryHighlightVerse: Int?
    private let targetVerse: Int?

    init(book: BibleBook, chapter: Int, targetVerse: Int? = nil) {
        self._currentBook = State(initialValue: book)
        self._currentChapter = State(initialValue: chapter)
        self.targetVerse = targetVerse
        if let targetVerse = targetVerse {
            print("🎯 VersesView initialized with target verse: \(book.name) \(chapter):\(targetVerse)")
        } else {
            print("📖 VersesView initialized without target verse: \(book.name) \(chapter)")
        }
    }

    @State private var verses: [BibleVerse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showError: Bool = false

    @State private var showNote: Bool = false
    @State private var noteText: String = ""
    @State private var verseHasNote: [Int: Bool] = [:]
    @State private var showAddNote: Bool = false
    @State private var draftNote: String = ""
    @State private var targetVerseForNote: BibleVerse?
    @State private var showAddCrossRef: Bool = false
    @State private var crossRefSource: BibleVerse? = nil
    @State private var pendingCrossRefId: UUID? = nil
    @State private var showCrossRefs: Bool = false
    @State private var showCrossRefDiscovery: Bool = false
    @State private var crossRefDiscoveryVerse: BibleVerse?
    @State private var multiSelect: Set<Int> = []
    @State private var lastScrollY: CGFloat = 0
    @State private var items: [ChapterItem] = []
    @State private var navigateToRandom: RandomChapterDestination? = nil
    @State private var showToastFlag: Bool = false
    @State private var toastMessage: String = ""
    @State private var isInteractingWithHeader: Bool = false
    @State private var hideChrome: Bool = false
    @State private var showSplitStudy: Bool = false
    // Highlighter removed
    @State private var showTranslationPicker: Bool = false

    // Highlight selection state
    @State private var selectedVerses: Set<Int> = []
    @State private var isSelectingVerses: Bool = false
    @State private var showColorPicker: Bool = false
    @State private var colorPickerPosition: CGPoint = .zero
    @State private var longPressStartVerse: Int?
    @State private var dragStartVerse: Int?
    @GestureState private var isLongPressing: Bool = false

    struct RandomChapterDestination: Hashable {
        let bookId: Int
        let bookName: String
        let chapter: Int
    }
    

    var body: some View {
        ScrollViewReader { proxy in
            List {
            // Fallback rendering when items are empty (defensive against empty datasets)
            if items.isEmpty && isLoading == false {
                ForEach(verses) { v in
                    HStack(alignment: .top, spacing: 8) {
                        if multiSelect.isEmpty == false {
                            Image(systemName: multiSelect.contains(v.verse) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(multiSelect.contains(v.verse) ? .blue : .secondary)
                                .onTapGesture { toggleSelect(v.verse) }
                        }
                        Text("\(v.verse)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        Text(v.text)
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .modifier(VerseHighlightModifier(verse: v.verse, highlights: highlights, bookId: currentBook.id, chapter: currentChapter))
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(
                        temporaryHighlightVerse == v.verse ? 
                        Color.yellow.opacity(0.3) : Color.clear
                    )
                    .id("verse-\(v.verse)")
                    .onTapGesture {
                        if multiSelect.isEmpty {
                            // If no verses are selected, select this one and show color picker
                            selectedVerses = [v.verse]
                            showColorPicker = true
                        } else {
                            // If in multi-select mode, toggle this verse
                            toggleSelect(v.verse)
                        }
                    }
                }
            }

            ForEach(items) { item in
                switch item {
                case .heading(let text, let verse):
                    headingRow(text: text, nextVerse: verse)
                case .verse(let v):
                    HStack(alignment: .top, spacing: 8) {
                    if multiSelect.isEmpty == false {
                        Image(systemName: multiSelect.contains(v.verse) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(multiSelect.contains(v.verse) ? .blue : .secondary)
                            .onTapGesture { toggleSelect(v.verse) }
                    }
                    // Highlighter removed
                    Text("\(v.verse)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    Group {
                        if v.verse == 1 {
                            firstLineIndentedText(v.text, indent: 24)
                        } else {
                            Text(v.text)
                        }
                    }
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .modifier(VerseHighlightModifier(verse: v.verse, highlights: highlights, bookId: currentBook.id, chapter: currentChapter))
                    if verseHasNote[v.verse] == true {
                        Button(action: { Task { await loadFootnote(for: v) } }) {
                            Text("ᵃ")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if case let .verse(v) = item {
                        if multiSelect.isEmpty {
                            // If no verses are selected, select this one and show color picker
                            selectedVerses = [v.verse]
                            showColorPicker = true
                        } else {
                            // If in multi-select mode, toggle this verse
                            toggleSelect(v.verse)
                        }
                    }
                }
                .contextMenu {
                    if case let .verse(v) = item {
                        Button { 
                            crossRefDiscoveryVerse = v
                            showCrossRefDiscovery = true
                        } label: {
                            Label("View References", systemImage: "arrow.triangle.branch")
                                .font(.body)
                        }
                        Button { addBookmark(for: v) } label: {
                            Label("Bookmark", systemImage: "bookmark")
                                .font(.body)
                        }
                        Button { targetVerseForNote = v; draftNote = ""; showAddNote = true } label: {
                            Label("Add Note", systemImage: "square.and.pencil")
                                .font(.body)
                        }
                        Button { enterMultiSelect(startingWith: v.verse) } label: {
                            Label("Select Verses", systemImage: "checklist")
                                .font(.body)
                        }
                        Button { openCrossReferenceFor(v) } label: {
                            Label("Add Cross Reference", systemImage: "link")
                                .font(.body)
                        }
                        Button { copySingle(v) } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.body)
                        }
                        // Highlighter context removed
                    }
                }
                .listRowInsets(rowInsets(for: item))
                .listRowSeparator(.hidden)
                .listRowBackground(
                    Group {
                        if case let .verse(v) = item, temporaryHighlightVerse == v.verse {
                            Color.yellow.opacity(0.3)
                        } else {
                            Color.clear
                        }
                    }
                )
                .id(item.verseId)
                .background(
                    Group {
                        if item.id == items.first?.id {
                            GeometryReader { proxy in
                                Color.clear.preference(key: VersesScrollOffsetKey.self, value: proxy.frame(in: .named("versesList")).minY)
                            }
                        }
                    }
                )
                .task {
                    if case let .verse(v) = item {
                        if verseHasNote[v.verse] == nil {
                            if let _ = try? await BibleService.shared.fetchFirstFootnoteText(bookId: v.book_id, chapter: v.chapter, verse: v.verse) {
                                verseHasNote[v.verse] = true
                            } else {
                                verseHasNote[v.verse] = false
                            }
                        }
                    }
                }
                }
            }
        }
        .id("list-\(currentBook.id)-\(currentChapter)")
        .coordinateSpace(name: "versesList")
        .onChangeCompat(items) {
            // Scroll to target verse when items are loaded
            if let targetVerse = targetVerse, !items.isEmpty {
                print("📜 VersesView: Items loaded, scrolling to verse \(targetVerse)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎯 VersesView: Attempting to scroll to verse-\(targetVerse)")
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("verse-\(targetVerse)", anchor: .center)
                    }
                }
            }
        }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .audioError).receive(on: DispatchQueue.main)) { notif in
            if let info = notif.userInfo as? [String: Any], let msg = info["message"] as? String {
                toastMessage = msg
            } else {
                toastMessage = "Unable to start audio."
            }
            withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = false }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // No custom back; rely on default system back when present
            ToolbarItem(placement: .navigationBarTrailing) {
                if multiSelect.isEmpty == false {
                    Button("Save") { saveMultiBookmark() }
                }
            }
        }
        .navigationDestination(item: $navigateToRandom) { destination in
            let book = BibleBook(id: destination.bookId, name: destination.bookName, abbreviation: "", testament: nil, chapters: 150)
            VersesView(book: book, chapter: destination.chapter)
        }
        .task { await setup() }
        .task {
            // Trigger temporary highlight if navigating to specific verse
            if let targetVerse = targetVerse {
                temporaryHighlightVerse = targetVerse
                // Clear the highlight after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 0.5)) {
                    temporaryHighlightVerse = nil
                }
            }
        }
        .onAppear {
            // If sanitation resulted in no verses, attempt one fallback refetch
            if verses.isEmpty {
                Task { await tryRefetchIfEmpty() }
            }
        }
        .overlay { if isLoading { ProgressView().allowsHitTesting(false) } }
        .overlay(alignment: .bottom) {
            if showToastFlag {
                Text(toastMessage)
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 80)
                    .transition(.opacity)
            }
        }
        .listStyle(.plain)
        .modifier(_CompactListTopMargin())
        .removeListTopPaddingIfAvailable()
        .hideListBackgroundIfAvailable()
        .environment(\.editMode, .constant(.inactive)) // Disable edit mode
        .selectionDisabled() // Disable selection entirely
        // Highlighter overlay removed
        .onPreferenceChange(VersesScrollOffsetKey.self) { y in
            let dy = y - lastScrollY
            // When pulling content up (finger scrolls down), y decreases → dy < 0
            if dy < -8 && isInteractingWithHeader == false {
                if hideChrome == false { withAnimation(.easeInOut(duration: 0.2)) { hideChrome = true } }
            } else if dy > 8 {
                if hideChrome == true { withAnimation(.easeInOut(duration: 0.2)) { hideChrome = false } }
            }
            lastScrollY = y
        }
        .onChangeCompat(currentChapter) {
            Task { await load() }
        }
        .onChangeCompat(translation.version) {
            errorMessage = nil
            showError = false
            Task { await load() }
        }
        // Monitor vertical drag to hide/show chrome while allowing list to scroll normally
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    guard isInteractingWithHeader == false else { return }
                    let dy = value.translation.height
                    if dy < -10 {
                        if hideChrome == false { withAnimation(.easeInOut(duration: 0.2)) { hideChrome = true } }
                    } else if dy > 10 {
                        if hideChrome == true { withAnimation(.easeInOut(duration: 0.2)) { hideChrome = false } }
                    }
                }
        )
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    guard isInteractingWithHeader == false else { return }
                    let horizontalTranslation = value.translation.width
                    if horizontalTranslation < -60 {
                        goToNextChapter()
                    } else if horizontalTranslation > 60 {
                        goToPreviousChapter()
                    }
                }
        )
        .safeAreaInset(edge: .bottom) {
            ZStack {
                // Controls bar (visible when palette hidden)
                HStack {
                    Button(action: { goToPreviousChapter() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Prev")
                        }
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(hideChrome || !canGoPrevious())
                    .opacity(hideChrome ? 0 : (canGoPrevious() ? 1 : 0.5))

                    Spacer(minLength: 20)

                    // Center play button (always visible)
                    Button(action: {
                        toastMessage = "Loading audio…"
                        withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = false }
                        }
                        AudioService.shared.togglePlay(book: currentBook, chapter: currentChapter)
                    }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 56, height: 56)
                            Image(systemName: AudioService.shared.isPlaying(book: currentBook, chapter: currentChapter) ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 20)

                    Button(action: { goToNextChapter() }) {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(hideChrome || !canGoNext())
                    .opacity(hideChrome ? 0 : (canGoNext() ? 1 : 0.5))
                }
                // Highlighter removed

                // Highlighter palette removed
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 84) // keep constant bottom height to avoid content shift
        }
        .safeAreaInset(edge: .top) {
            if hideChrome == false {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        // Book + Chapter → navigate to books/chapters
                        Button(action: { bibleRouter.goToBooksRoot() }) {
                            HStack(spacing: 6) {
                                Text("\(currentBook.name) \(currentChapter)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded { bibleRouter.goToBooksRoot() })
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in isInteractingWithHeader = true }
                                .onEnded { _ in isInteractingWithHeader = false }
                        )

                        if let v = verses.first {
                            // Version chip → open translation picker
                            Button(action: { showTranslationPicker = true }) {
                                Text(v.version)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            Button(action: { showSplitStudy = true }) {
                                Image(systemName: "square.split.2x1")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            Button(action: goToRandomChapter) {
                                Image(systemName: "shuffle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showSplitStudy) {
            SplitStudyView(initialBook: currentBook, initialChapter: currentChapter)
        }
        .sheet(isPresented: $showTranslationPicker) {
            NavigationStack {
                List {
                    Section("Translation") {
                        ForEach(TranslationService.shared.available, id: \.self) { v in
                            HStack {
                                Text(v)
                                Spacer()
                                if v == translation.version { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                translation.version = v
                                showTranslationPicker = false
                            }
                        }
                    }
                }
                .navigationTitle("Choose Version")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showTranslationPicker = false } } }
            }
        }
        .sheet(isPresented: $showNote) {
            ZStack {
                VisualEffectBlur(material: .systemUltraThinMaterial)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 40, height: 4)
                    Text("Footnote").font(.headline)
                    ScrollView {
                        Text(noteText)
                            .font(.footnote)
                            .foregroundColor(.primary)
                            .padding()
                    }
                    Button("Close") { showNote = false }
                        .buttonStyle(.bordered)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 360)
                .padding()
            }
        }
        .sheet(isPresented: $showAddNote) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Note for \(currentBook.name) \(currentChapter):\(targetVerseForNote?.verse ?? 0)").font(.headline)
                    TextEditor(text: $draftNote)
                        .frame(minHeight: 160)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    HStack {
                        Spacer()
                        Button("Save") { saveNote() }.buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .navigationTitle("New Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showAddNote = false } } }
            }
        }
        .sheet(isPresented: $showAddCrossRef) {
            if let source = crossRefSource {
                AddCrossReferenceSheet(
                    source: source,
                    sourceBookName: currentBook.name,
                    books: allBooks.isEmpty ? [currentBook] : allBooks,
                    defaultTargetBook: currentBook,
                    onCancel: { showAddCrossRef = false },
                    onSaved: { id in
                        toast("Cross reference added")
                        showAddCrossRef = false
                        // Present the map with focus id on next runloop to ensure dismissal completes
                        DispatchQueue.main.async {
                            pendingCrossRefId = id
                            showCrossRefs = true
                        }
                    }
                )
            }
        }
        // Present CrossReferencesView after save
        .sheet(isPresented: $showCrossRefs) {
            CrossRefMapModal(focusId: pendingCrossRefId)
        }
        // Present CrossReferenceDiscoveryView
        .sheet(isPresented: $showCrossRefDiscovery) {
            if let verse = crossRefDiscoveryVerse {
                CrossReferenceDiscoveryView(verse: verse, bookName: currentBook.name)
                    .environmentObject(bibleRouter)
            }
        }
        .overlay {
            if showColorPicker {
                ColorPickerView(
                    onColorSelected: { colorHex in
                        applyHighlight(colorHex: colorHex)
                        showColorPicker = false
                    },
                    onCancel: {
                        showColorPicker = false
                        selectedVerses.removeAll()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom))
            }
            
            // Error popup overlay
            if showError, let errorMessage = errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Translation Unavailable")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showError)
            }
        }
    }

    private func share(verse: BibleVerse) {
        let text = "\(currentBook.name) \(currentChapter):\(verse.verse) — \(verse.text)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        presentActivityController(av)
    }

    private func addBookmark(for v: BibleVerse) {
        let b = Bookmark(bookId: v.book_id, bookName: currentBook.name, chapter: v.chapter, verse: v.verse, text: v.text)
        LibraryService.shared.addBookmark(b)
    }

    private func enterMultiSelect(startingWith verse: Int) { multiSelect = [verse] }
    private func toggleSelect(_ verse: Int) {
        if multiSelect.contains(verse) { multiSelect.remove(verse) } else { multiSelect.insert(verse) }
    }
    private func saveMultiBookmark() {
        let selected = verses.filter { multiSelect.contains($0.verse) }.sorted { $0.verse < $1.verse }
        guard let first = selected.first else { return }
        let combined = selected.map { $0.text }.joined(separator: " ")
        let b = Bookmark(bookId: first.book_id, bookName: currentBook.name, chapter: first.chapter, verse: first.verse, verses: selected.map { $0.verse }, text: combined)
        LibraryService.shared.addBookmark(b)
        multiSelect.removeAll()
    }

    private func copySingle(_ v: BibleVerse) {
        UIPasteboard.general.string = shareString([v])
        toast("Copied \(currentBook.name) \(currentChapter):\(v.verse)")
    }

    private func copySelected() {
        let selected = verses.filter { multiSelect.contains($0.verse) }.sorted { $0.verse < $1.verse }
        guard selected.isEmpty == false else { return }
        UIPasteboard.general.string = shareString(selected)
        let rangeDesc = selected.count == 1 ? "\(selected.first!.verse)" : "\(selected.first!.verse)-\(selected.last!.verse)"
        toast("Copied \(currentBook.name) \(currentChapter):\(rangeDesc)")
        multiSelect.removeAll()
    }

    private func shareString(_ list: [BibleVerse]) -> String {
        list.map { "\(currentBook.name) \(currentChapter):\($0.verse) — \($0.text)" }.joined(separator: "\n\n")
    }

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) { showToastFlag = false }
        }
    }

    private func saveNote() {
        guard let v = targetVerseForNote, !draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let n = UserNote(bookId: v.book_id, bookName: currentBook.name, chapter: v.chapter, verse: v.verse, text: draftNote)
        LibraryService.shared.addNote(n)
        showAddNote = false
    }

    private func openCrossReferenceFor(_ v: BibleVerse) {
        crossRefSource = v
        showAddCrossRef = true
    }

    // Highlighter removed

    private func openBooksList() {
        NotificationCenter.default.post(name: .openBibleTab, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            NotificationCenter.default.post(name: .openBooksList, object: nil)
        }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedVerses = try await BibleService.shared.fetchVerses(bookId: currentBook.id, chapter: currentChapter)
            
            await MainActor.run {
                verses = fetchedVerses
                items = ChapterItem.build(from: verses)
                // Persist last read for HomeView continue button
                UserDefaults.standard.set(currentBook.id, forKey: "lastBookId")
                UserDefaults.standard.set(currentBook.name, forKey: "lastBookName")
                UserDefaults.standard.set(currentChapter, forKey: "lastChapter")
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                showError = true
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showError = false
                    }
                }
            }
        }
    }

    private func tryRefetchIfEmpty() async {
        do {
            let fresh = try await BibleService.shared.fetchVerses(bookId: currentBook.id, chapter: currentChapter)
            if fresh.isEmpty == false {
                verses = fresh
                items = ChapterItem.build(from: fresh)
            }
        } catch { }
    }

    private func setup() async {
        do {
            if allBooks.isEmpty {
                allBooks = try await BibleService.shared.fetchBooks()
            }
        } catch { }
        await load()
    }

    private func goToNextChapter() {
        if currentChapter < currentBook.chapters {
            currentChapter += 1
            return
        }
        if let idx = allBooks.firstIndex(where: { $0.id == currentBook.id }), idx < allBooks.count - 1 {
            currentBook = allBooks[idx + 1]
            currentChapter = 1
        }
    }

    private func goToRandomChapter() {
        Task {
            // Ensure books are loaded
            if allBooks.isEmpty {
                do {
                    allBooks = try await BibleService.shared.fetchBooks()
                } catch {
                    return // Failed to load books
                }
            }

            guard !allBooks.isEmpty else { return }

            // Select random book
            let randomBook = allBooks.sorted { a, b in
                BibleService.shared.canonicalOrderIndex(for: a.name) < BibleService.shared.canonicalOrderIndex(for: b.name)
            }.randomElement()!

            // Select random chapter (1 to book's total chapters)
            let randomChapter = Int.random(in: 1...randomBook.chapters)

            // Navigate to the random chapter
            navigateToRandom = RandomChapterDestination(bookId: randomBook.id, bookName: randomBook.name, chapter: randomChapter)
        }
    }

    private func goToPreviousChapter() {
        if currentChapter > 1 {
            currentChapter -= 1
            return
        }
        if let idx = allBooks.firstIndex(where: { $0.id == currentBook.id }), idx > 0 {
            let prevBook = allBooks[idx - 1]
            currentBook = prevBook
            currentChapter = prevBook.chapters
        }
    }

    private func canGoNext() -> Bool {
        guard let idx = allBooks.firstIndex(where: { $0.id == currentBook.id }) else {
            return currentChapter < currentBook.chapters
        }
        if idx == allBooks.count - 1 { // last book (Revelation)
            return currentChapter < currentBook.chapters
        }
        return true
    }

    private func canGoPrevious() -> Bool {
        guard let idx = allBooks.firstIndex(where: { $0.id == currentBook.id }) else {
            return currentChapter > 1
        }
        if idx == 0 { // first book (Genesis)
            return currentChapter > 1
        }
        return true
    }

    private func loadFootnote(for verse: BibleVerse) async {
        do {
            let notes = try await BibleService.shared.fetchFootnotes(bookId: verse.book_id, chapter: verse.chapter, verse: verse.verse)
            if let n = notes.first {
                noteText = n.text
                showNote = true
            }
        } catch { }
    }

    // MARK: - Highlight functionality

    private func applyHighlight(colorHex: String?) {
        guard !selectedVerses.isEmpty else { return }

        if let colorHex = colorHex {
            // Apply highlight to each selected verse
            for verse in selectedVerses {
                highlights.setHighlight(
                    bookId: currentBook.id,
                    chapter: currentChapter,
                    startVerse: verse,
                    endVerse: verse,
                    colorHex: colorHex
                )
            }
        } else {
            // Remove highlight from each selected verse
            for verse in selectedVerses {
                highlights.removeHighlight(
                    bookId: currentBook.id,
                    chapter: currentChapter,
                    startVerse: verse,
                    endVerse: verse
                )
            }
        }

        selectedVerses.removeAll()
    }
}

// MARK: - Verse Highlight Modifier
private struct VerseHighlightModifier: ViewModifier {
    let verse: Int
    @ObservedObject var highlights: HighlightService
    let bookId: Int
    let chapter: Int

    func body(content: Content) -> some View {
        content.background(
            highlights.colorForVerse(bookId: bookId, chapter: chapter, verse: verse) != nil ?
                Color(hex: highlights.colorForVerse(bookId: bookId, chapter: chapter, verse: verse) ?? "#FFFF00").opacity(0.3) :
                Color.clear
        )
    }
}


// Generic number picker sheet (used for Chapter / Verse)
private struct NumberPickerSheet: View {
    let title: String
    let numbers: [Int]
    @Binding var selected: Int
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(numbers, id: \.self) { n in
                HStack {
                    Text("\(n)")
                    Spacer()
                    if n == selected { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = n; onClose() }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { onClose() } } }
        }
    }
}

// Simple blur wrapper
struct VisualEffectBlur: UIViewRepresentable {
    var material: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: material))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: material)
    }
}

// MARK: - Compact list top margin helper
private struct _CompactListTopMargin: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.vertical, 0, for: .scrollContent)
                .listSectionSpacing(.compact)
        } else if #available(iOS 16.0, *) {
            content
                .listSectionSpacing(.compact)
        } else {
            content
        }
    }
}

// MARK: - View helpers
private extension View {
    @ViewBuilder
    func hideListBackgroundIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func removeListTopPaddingIfAvailable() -> some View {
        if #available(iOS 15.0, *) {
            self.listRowSpacing(0)
        } else {
            self
        }
    }

    // iOS 17 introduced a new onChange signature. Provide a compat helper.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(_ value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, _ in action() }
        } else {
            self.onChange(of: value) { _ in action() }
        }
    }
}

// closeAllBooks moved to Models/Notifications.swift

// MARK: - Heading detection (very lightweight heuristics)
// Removed heading extraction; render verses exactly as provided

// MARK: - Scroll tracking key
private struct VersesScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - First verse indent
// Build a Text whose first line is indented by `indent` points; subsequent lines are flush
private func firstLineIndentedText(_ string: String, indent: CGFloat) -> Text {
    if #available(iOS 15.0, *) {
        let ns = NSMutableParagraphStyle()
        ns.firstLineHeadIndent = indent
        ns.headIndent = 0
        let nsAttr = NSAttributedString(string: string, attributes: [
            .paragraphStyle: ns
        ])
        return Text(AttributedString(nsAttr))
    } else {
        let spaces = String(repeating: "\u{00A0}", count: 4)
        return Text(spaces + string)
    }
}

// MARK: - UIKit helpers
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

// Lightweight toast
// (Removed UIKit toast; SwiftUI overlay is used instead)

// MARK: - Chapter display items & helpers
private enum ChapterItem: Identifiable, Equatable {
    case heading(text: String, nextVerse: Int)
    case verse(BibleVerse)
    
    static func == (lhs: ChapterItem, rhs: ChapterItem) -> Bool {
        lhs.id == rhs.id
    }

    var id: String {
        switch self {
        case .heading(let text, let v): return "h-\(v)-\(text)"
        case .verse(let v): return "v-\(v.id)"
        }
    }
    
    var verseId: String {
        switch self {
        case .heading(let _, let v): return "verse-\(v)"
        case .verse(let v): return "verse-\(v.verse)"
        }
    }

    static func build(from verses: [BibleVerse]) -> [ChapterItem] {
        var result: [ChapterItem] = []
        var lastHeading: String? = nil

        // Get book name for header lookup
        let bookName = verses.first.flatMap { BibleService.shared.getBookName(byId: $0.book_id) } ?? ""

        for v in verses {
            var headingForThisVerse: String? = v.heading?.trimmingCharacters(in: .whitespacesAndNewlines)
            var textForThisVerse: String = v.text

            // First priority: Check Header.md for this specific verse
            if let headerMdHeading = HeaderService.shared.getHeading(forBook: bookName, chapter: v.chapter, verse: v.verse) {
                headingForThisVerse = headerMdHeading
            }

            // Fallback: only for BSB, if verse 1 has embedded heading in text, split it
            if (headingForThisVerse == nil || headingForThisVerse == "") && v.verse == 1 {
                if v.version.uppercased().contains("BSB") {
                    let split = BibleService.extractInlineHeading(from: v.text)
                    if let h = split.heading, !h.isEmpty {
                        headingForThisVerse = h
                        textForThisVerse = split.body
                    }
                }
            }

            if let h = headingForThisVerse, h.isEmpty == false {
                if lastHeading != h {
                    result.append(.heading(text: h, nextVerse: v.verse))
                    lastHeading = h
                }
            }
            let vv = BibleVerse(id: v.id, book_id: v.book_id, chapter: v.chapter, verse: v.verse, text: textForThisVerse, version: v.version, heading: headingForThisVerse)
            result.append(.verse(vv))
        }
        return result
    }
}

// MARK: - Add Cross Reference Sheet
private struct AddCrossReferenceSheet: View {
    let source: BibleVerse
    let sourceBookName: String
    let books: [BibleBook]
    let onCancel: () -> Void
    let onSaved: (UUID) -> Void

    @State private var selectedBook: BibleBook
    @State private var chapterInt: Int
    @State private var verseInt: Int
    @State private var note: String = ""
    @State private var showBookPicker: Bool = false
    @State private var showChapterPicker: Bool = false
    @State private var showVersePicker: Bool = false
    @State private var verseMax: Int = 50
    @State private var showNotInIndexAlert: Bool = false
    @State private var pendingSaveLine: CrossReferenceLine? = nil
    @State private var isChecking: Bool = false

    init(source: BibleVerse, sourceBookName: String, books: [BibleBook], defaultTargetBook: BibleBook, onCancel: @escaping () -> Void, onSaved: @escaping (UUID) -> Void) {
        self.source = source
        self.sourceBookName = sourceBookName
        self.books = books
        self.onCancel = onCancel
        self.onSaved = onSaved
        _selectedBook = State(initialValue: defaultTargetBook)
        _chapterInt = State(initialValue: 1)
        _verseInt = State(initialValue: 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "link").foregroundColor(.accentColor)
                        Text("\(sourceBookName) \(source.chapter):\(source.verse)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("To").font(.subheadline).foregroundColor(.secondary)
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showBookPicker = true } }) {
                            HStack {
                                Text(selectedBook.name).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Chapter").font(.caption).foregroundColor(.secondary)
                            Button(action: { showChapterPicker = true }) {
                                HStack {
                                    Text("\(chapterInt)").font(.headline).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Verse").font(.caption).foregroundColor(.secondary)
                            Button(action: { showVersePicker = true }) {
                                HStack {
                                    Text("\(verseInt)").font(.headline).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)").font(.subheadline).foregroundColor(.secondary)
                        TextField("Add a note…", text: $note)
                            .textFieldStyle(.roundedBorder)
                    }

                    Spacer(minLength: 0)

                    // Enhanced Add button with landscape suggestion
                    VStack(spacing: 4) {
                        Button(action: {
                            // Save the cross reference
                            attemptSave()
                        }) {
                            Text("Add")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isValid == false || isChecking)

                        // Landscape mode hint
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Best viewed in landscape")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Cross Reference")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } } }
            .sheet(isPresented: $showBookPicker) {
                BookPickerSheet(books: books, selected: $selectedBook) {
                    showBookPicker = false
                    if chapterInt > selectedBook.chapters { chapterInt = selectedBook.chapters }
                }
            }
            .sheet(isPresented: $showChapterPicker) {
                NumberPickerSheet(title: "Choose Chapter", numbers: Array(1...max(1, selectedBook.chapters)), selected: $chapterInt) {
                    showChapterPicker = false
                }
            }
            .sheet(isPresented: $showVersePicker) {
                NumberPickerSheet(title: "Choose Verse", numbers: Array(1...max(1, verseMax)), selected: $verseInt) {
                    showVersePicker = false
                }
            }
            .onChange(of: selectedBook.id) { _ in
                Task { await refreshVerseMax() }
            }
            .onChange(of: chapterInt) { _ in
                Task { await refreshVerseMax() }
            }
            .task { await refreshVerseMax() }
            .alert("Cross reference not found in curated list", isPresented: $showNotInIndexAlert) {
                Button("Cancel", role: .cancel) { pendingSaveLine = nil }
                Button("Connect", role: .none) {
                    guard let line = pendingSaveLine else { return }
                    LibraryService.shared.addCrossReference(line)
                    onSaved(line.id)
                    pendingSaveLine = nil
                }
            } message: {
                Text("This connection isn’t in the curated index. Do you want to add it anyway?")
            }
            .overlay {
                if isChecking {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            Text("Checking Reference").font(.headline).foregroundColor(.primary)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(radius: 10)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var isValid: Bool {
        chapterInt > 0 && verseInt > 0
    }

    private func attemptSave() {
        let c = chapterInt
        let v = verseInt
        let line = CrossReferenceLine(
            sourceBookId: source.book_id,
            sourceBookName: sourceBookName,
            sourceChapter: source.chapter,
            sourceVerse: source.verse,
            targetBookId: selectedBook.id,
            targetBookName: selectedBook.name,
            targetChapter: c,
            targetVerse: v,
            note: note.isEmpty ? nil : note
        )
        isChecking = true
        Task(priority: .userInitiated) {
            let isIndexed = CrossReferenceIndexService.shared.contains(
                sourceBookName: sourceBookName,
                sourceChapter: source.chapter,
                sourceVerse: source.verse,
                targetBookName: selectedBook.name,
                targetChapter: c,
                targetVerse: v
            )
            await MainActor.run {
                isChecking = false
                if isIndexed {
                    LibraryService.shared.addCrossReference(line)
                    onSaved(line.id)
                } else {
                    pendingSaveLine = line
                    showNotInIndexAlert = true
                }
            }
        }
    }

    // MARK: - Verse counts
    private func refreshVerseMax() async {
        let bookId = selectedBook.id
        let chapter = chapterInt
        do {
            let verses = try await BibleService.shared.fetchVerses(bookId: bookId, chapter: chapter)
            let maxVerse = verses.map { $0.verse }.max() ?? 50
            await MainActor.run {
                verseMax = max(1, maxVerse)
                if verseInt > verseMax { verseInt = verseMax }
            }
        } catch {
            await MainActor.run {
                verseMax = 50
                if verseInt > verseMax { verseInt = verseMax }
            }
        }
    }
}

private struct BookPickerSheet: View {
    let books: [BibleBook]
    @Binding var selected: BibleBook
    let onClose: () -> Void
    @State private var query: String = ""

    private var filtered: [BibleBook] {
        let ordered = books.sorted { a, b in
            BibleService.shared.canonicalOrderIndex(for: a.name) < BibleService.shared.canonicalOrderIndex(for: b.name)
        }
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return ordered }
        let q = query.lowercased()
        return ordered.filter { $0.name.lowercased().contains(q) || $0.abbreviation.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.id) { b in
                HStack {
                    Text(b.name)
                    Spacer()
                    if b.id == selected.id { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                }
                .contentShape(Rectangle())
                .onTapGesture { selected = b; onClose() }
            }
            .searchable(text: $query)
            .navigationTitle("Choose Book")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { onClose() } } }
        }
    }
}

@ViewBuilder
private func headingRow(text: String, nextVerse: Int) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .default))
            .foregroundColor(.primary)
    }
}

private func rowInsets(for item: ChapterItem) -> EdgeInsets {
    switch item {
    case .heading(_, let nextVerse):
        return EdgeInsets(top: nextVerse == 1 ? -10 : 8, leading: 20, bottom: 2, trailing: 20)
    case .verse(let v):
        return EdgeInsets(top: v.verse == 1 ? -4 : 6, leading: 20, bottom: 8, trailing: 20)
    }
}

// Highlighter helpers removed
