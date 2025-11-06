import SwiftUI

struct CrossReferenceDiscoveryView: View {
    let verse: BibleVerse
    let bookName: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bibleRouter: BibleRouter
    @State private var crossReferences: [CrossReference] = []
    @State private var isLoading = true
    @State private var showAllReferences = false
    @State private var selectedReference: CrossReference?
    @State private var showPreview = false
    
    private var displayedReferences: [CrossReference] {
        if showAllReferences {
            return crossReferences
        } else {
            return Array(crossReferences.prefix(5))
        }
    }
    
    private var hasMoreReferences: Bool {
        crossReferences.count > 5
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                
                                Text("Cross References")
                                    .font(.title2.bold())
                            }
                            
                            VStack(spacing: 8) {
                                Text("\(bookName) \(verse.chapter):\(verse.verse)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(verse.text)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .lineLimit(3)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding(.top)
                        
                        if !isLoading {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Text("\(crossReferences.count) \(crossReferences.count == 1 ? "Reference" : "References") Found")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(crossReferences.isEmpty ? Color.gray : Color.accentColor)
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if crossReferences.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No Cross References")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("This verse doesn't have any cross-references in our database yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(Array(displayedReferences.enumerated()), id: \.element.toVerse) { index, reference in
                                    CrossReferenceCard(
                                        reference: reference,
                                        rank: index + 1,
                                        onTap: {
                                            navigateToReference(reference)
                                        }
                                    )
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                }
                                
                                if hasMoreReferences && !showAllReferences {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            showAllReferences = true
                                        }
                                    }) {
                                        HStack {
                                            Text("Show \(crossReferences.count - 5) More")
                                                .font(.subheadline.bold())
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.accentColor)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                        .background(
                                            Capsule()
                                                .stroke(Color.accentColor, lineWidth: 2)
                                        )
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await loadCrossReferences()
        }
    }
    
    private func loadCrossReferences() async {
        isLoading = true
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        crossReferences = CrossReferenceService.shared.getCrossReferences(
            for: bookName,
            chapter: verse.chapter,
            verse: verse.verse
        )
        
        withAnimation(.spring()) {
            isLoading = false
        }
    }
    
    private func navigateToReference(_ reference: CrossReference) {
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let fullBookName = CrossReferenceService.shared.getFullBookName(from: reference.toBook)
            
            bibleRouter.goToVerse(
                bookName: fullBookName,
                chapter: reference.toChapter,
                verse: reference.toVerseNumber
            )
        }
    }
}

struct CrossReferenceCard: View {
    let reference: CrossReference
    let rank: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var popularityLevel: String {
        if reference.votes > 200 {
            return "🔥 Highly Popular"
        } else if reference.votes > 100 {
            return "⭐️ Very Popular"
        } else if reference.votes > 50 {
            return "✨ Popular"
        } else {
            return ""
        }
    }
    
    private var popularityColor: Color {
        if reference.votes > 200 {
            return .orange
        } else if reference.votes > 100 {
            return .yellow
        } else if reference.votes > 50 {
            return .blue
        } else {
            return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rank <= 3 ? Color.accentColor : Color(.tertiarySystemBackground))
                        .frame(width: 36, height: 36)
                    
                    Text("\(rank)")
                        .font(.caption.bold())
                        .foregroundColor(rank <= 3 ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(reference.displayText)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if !popularityLevel.isEmpty {
                            Text(popularityLevel)
                                .font(.caption.bold())
                                .foregroundColor(popularityColor)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(reference.votes) votes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(isPressed ? 0.1 : 0.05), radius: isPressed ? 2 : 4, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}
