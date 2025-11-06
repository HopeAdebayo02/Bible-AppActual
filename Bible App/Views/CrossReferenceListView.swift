import SwiftUI

struct CrossReferenceListView: View {
    let verse: BibleVerse
    let bookName: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bibleRouter: BibleRouter
    
    @State private var crossReferences: [CrossReference] = []
    @State private var referencesToVerse: [CrossReference] = []
    @State private var showSplitStudy = false
    @State private var selectedCrossRef: CrossReference?
    
    var body: some View {
        NavigationView {
            List {
                if !crossReferences.isEmpty {
                    Section("References from \(bookName) \(verse.chapter):\(verse.verse)") {
                        ForEach(crossReferences.indices, id: \.self) { index in
                            CrossReferenceRow(
                                crossRef: crossReferences[index],
                                onTap: { navigateToReference(crossReferences[index]) }
                            )
                        }
                    }
                }
                
                if !referencesToVerse.isEmpty {
                    Section("References to \(bookName) \(verse.chapter):\(verse.verse)") {
                        ForEach(referencesToVerse.indices, id: \.self) { index in
                            CrossReferenceRow(
                                crossRef: referencesToVerse[index],
                                isReverse: true,
                                onTap: { navigateToReverseReference(referencesToVerse[index]) }
                            )
                        }
                    }
                }
                
                if crossReferences.isEmpty && referencesToVerse.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "link.circle")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Cross References Found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("No cross-references are available for \(bookName) \(verse.chapter):\(verse.verse)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .navigationTitle("Cross References")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCrossReferences()
            }
            .sheet(isPresented: $showSplitStudy) {
                if let crossRef = selectedCrossRef {
                    SplitStudyViewForCrossReference(
                        originalVerse: verse,
                        originalBookName: bookName,
                        crossRef: crossRef
                    )
                }
            }
        }
    }
    
    private func loadCrossReferences() {
        let service = CrossReferenceService.shared
        
        // Get references from this verse to others
        crossReferences = service.getCrossReferences(
            for: bookName,
            chapter: verse.chapter,
            verse: verse.verse
        )
        
        // Get references from other verses to this one
        referencesToVerse = service.getReferencesToVerse(
            for: bookName,
            chapter: verse.chapter,
            verse: verse.verse
        )
    }
    
    private func navigateToReference(_ crossRef: CrossReference) {
        print("Tapping cross-reference: \(crossRef.displayText)")
        print("Original verse: \(bookName) \(verse.chapter):\(verse.verse)")
        selectedCrossRef = crossRef
        showSplitStudy = true
        print("showSplitStudy set to true")
    }
    
    private func navigateToReverseReference(_ crossRef: CrossReference) {
        print("Tapping reverse cross-reference: \(crossRef.fromVerse)")
        print("Original verse: \(bookName) \(verse.chapter):\(verse.verse)")
        selectedCrossRef = crossRef
        showSplitStudy = true
        print("showSplitStudy set to true")
    }
}

struct CrossReferenceRow: View {
    let crossRef: CrossReference
    var isReverse: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if isReverse {
                    Text(crossRef.fromVerse.replacingOccurrences(of: ".", with: " "))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text(crossRef.displayText)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(crossRef.votes) votes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
    
    CrossReferenceListView(verse: sampleVerse, bookName: "Genesis")
        .environmentObject(BibleRouter())
}
