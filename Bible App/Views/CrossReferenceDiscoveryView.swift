import SwiftUI

struct CrossReferenceDiscoveryView: View {
    let verse: BibleVerse
    let bookName: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bibleRouter: BibleRouter
    @State private var outgoingReferences: [CrossReference] = []
    @State private var incomingReferences: [CrossReference] = []
    @State private var isLoading = true
    @State private var showAllOutgoing = false
    @State private var showAllIncoming = false
    @State private var selectedReference: CrossReference?
    
    private var totalReferences: Int {
        outgoingReferences.count + incomingReferences.count
    }
    
    private var displayedOutgoing: [CrossReference] {
        if showAllOutgoing {
            return outgoingReferences
        } else {
            return Array(outgoingReferences.prefix(5))
        }
    }
    
    private var displayedIncoming: [CrossReference] {
        if showAllIncoming {
            return incomingReferences
        } else {
            return Array(incomingReferences.prefix(5))
        }
    }
    
    private var hasMoreOutgoing: Bool {
        outgoingReferences.count > 5
    }
    
    private var hasMoreIncoming: Bool {
        incomingReferences.count > 5
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
                                
                                Text("\(totalReferences) \(totalReferences == 1 ? "Reference" : "References") Found")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(totalReferences == 0 ? Color.gray : Color.accentColor)
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if totalReferences == 0 {
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
                            VStack(spacing: 24) {
                                if !outgoingReferences.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundColor(.blue)
                                            Text("This Verse References")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(outgoingReferences.count)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Color.blue))
                                        }
                                        .padding(.horizontal)
                                        
                                        VStack(spacing: 12) {
                                            ForEach(Array(displayedOutgoing.enumerated()), id: \.element.toVerse) { index, reference in
                                                CrossReferenceCard(
                                                    reference: reference,
                                                    rank: index + 1,
                                                    onTap: {
                                                        selectedReference = reference
                                                    }
                                                )
                                                .transition(.asymmetric(
                                                    insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity
                                                ))
                                            }
                                            
                                            if hasMoreOutgoing && !showAllOutgoing {
                                                Button(action: {
                                                    withAnimation(.spring()) {
                                                        showAllOutgoing = true
                                                    }
                                                }) {
                                                    HStack {
                                                        Text("Show \(outgoingReferences.count - 5) More")
                                                            .font(.subheadline.bold())
                                                        Image(systemName: "chevron.down")
                                                            .font(.caption)
                                                    }
                                                    .foregroundColor(.blue)
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 24)
                                                    .background(
                                                        Capsule()
                                                            .stroke(Color.blue, lineWidth: 2)
                                                    )
                                                }
                                                .padding(.top, 8)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                if !incomingReferences.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "arrow.left.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Verses That Reference This")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(incomingReferences.count)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Color.green))
                                        }
                                        .padding(.horizontal)
                                        
                                        VStack(spacing: 12) {
                                            ForEach(Array(displayedIncoming.enumerated()), id: \.element.toVerse) { index, reference in
                                                CrossReferenceCard(
                                                    reference: reference,
                                                    rank: index + 1,
                                                    onTap: {
                                                        selectedReference = reference
                                                    }
                                                )
                                                .transition(.asymmetric(
                                                    insertion: .scale.combined(with: .opacity),
                                                    removal: .opacity
                                                ))
                                            }
                                            
                                            if hasMoreIncoming && !showAllIncoming {
                                                Button(action: {
                                                    withAnimation(.spring()) {
                                                        showAllIncoming = true
                                                    }
                                                }) {
                                                    HStack {
                                                        Text("Show \(incomingReferences.count - 5) More")
                                                            .font(.subheadline.bold())
                                                        Image(systemName: "chevron.down")
                                                            .font(.caption)
                                                    }
                                                    .foregroundColor(.green)
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 24)
                                                    .background(
                                                        Capsule()
                                                            .stroke(Color.green, lineWidth: 2)
                                                    )
                                                }
                                                .padding(.top, 8)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
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
        .fullScreenCover(item: $selectedReference) { reference in
            SplitStudyViewForCrossReference(
                originalVerse: verse,
                originalBookName: bookName,
                crossRef: reference
            )
            .id(reference.id)
            .environmentObject(bibleRouter)
        }
        .task {
            await loadCrossReferences()
        }
    }
    
    private func loadCrossReferences() async {
        await MainActor.run {
            isLoading = true
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let outgoing = CrossReferenceService.shared.getCrossReferences(
            for: bookName,
            chapter: verse.chapter,
            verse: verse.verse
        )
        
        let incoming = CrossReferenceService.shared.getReferencesToVerse(
            for: bookName,
            chapter: verse.chapter,
            verse: verse.verse
        )
        
        await MainActor.run {
            outgoingReferences = outgoing
            incomingReferences = incoming
            
            withAnimation(.spring()) {
                isLoading = false
            }
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
