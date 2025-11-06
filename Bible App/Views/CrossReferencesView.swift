import SwiftUI

struct CrossReferencesView: View {
    let focusId: UUID?
    @Environment(\.dismiss) private var dismiss

    enum ViewMode {
        case map, table

        mutating func toggle() {
            self = self == .map ? .table : .map
        }
    }
    @ObservedObject private var library = LibraryService.shared
    @State private var books: [BibleBook] = []
    @State private var arcProgress: [UUID: CGFloat] = [:]
    @State private var arcHeadT: [UUID: CGFloat] = [:]
    @State private var hoveredArcId: UUID? = nil
    @State private var hoverLocation: CGPoint = .zero
    @State private var showClearAlert: Bool = false
    @State private var viewMode: ViewMode = .map
    @State private var selectedCrossReference: CrossReferenceLine?
    @State private var showConnectionDetail: Bool = false
    @EnvironmentObject private var bibleRouter: BibleRouter
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var pinchState: CGFloat = 1.0
    @GestureState private var dragState: CGSize = .zero
    @State private var isSeeding: Bool = false
    @State private var canvasContentSize: CGSize = .zero
    @State private var filterScope: FilterScope = .all
    @State private var densityLimit: Int? = nil
    @State private var selectedArcId: UUID? = nil
    
    enum FilterScope {
        case all, oldTestament, newTestament
    }

    // Computed property for landscape detection
    private var isCurrentlyLandscape: Bool {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return false }
        return window.bounds.width > window.bounds.height
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                if viewMode == .map {
                    HStack(spacing: 8) {
                        Button(action: { filterScope = .all }) {
                            Text("All")
                                .font(.caption.weight(.medium))
                                .foregroundColor(filterScope == .all ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterScope == .all ? Color.accentColor : Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Button(action: { filterScope = .oldTestament }) {
                            Text("OT")
                                .font(.caption.weight(.medium))
                                .foregroundColor(filterScope == .oldTestament ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterScope == .oldTestament ? Color.accentColor : Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Button(action: { filterScope = .newTestament }) {
                            Text("NT")
                                .font(.caption.weight(.medium))
                                .foregroundColor(filterScope == .newTestament ? .white : .secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filterScope == .newTestament ? Color.accentColor : Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button("Show All") { densityLimit = nil }
                            Button("Top 50") { densityLimit = 50 }
                            Button("Top 100") { densityLimit = 100 }
                            Button("Top 200") { densityLimit = 200 }
                        } label: {
                            HStack(spacing: 4) {
                                Text(densityLimit == nil ? "All" : "Top \(densityLimit!)")
                                    .font(.caption.weight(.medium))
                                Image(systemName: "line.3.horizontal.decrease.circle")
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                
                if viewMode == .map {
                Canvas { context, size in
                    // Performance optimization: only render when needed
                    let transform = CGAffineTransform(translationX: offset.width + dragState.width, y: offset.height + dragState.height)
                        .scaledBy(x: scale * pinchState, y: scale * pinchState)
                    context.concatenate(transform)

                    // Use cached size calculation for better performance
                    let cachedSize = size.applying(transform.inverted())
                    // Capture content size for accurate hit testing
                    DispatchQueue.main.async { self.canvasContentSize = cachedSize }

                    // Only draw if we have books loaded (prevents unnecessary rendering)
                    if !books.isEmpty {
                        drawBaseline(in: context, size: cachedSize)
                        drawArcs(in: context, size: cachedSize)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.edgesIgnoringSafeArea(.all))
                .animation(.easeInOut(duration: 0.6), value: arcProgress)
                .gesture(simultaneousGestures())
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Convert tap to content coordinates
                    let inv = CGAffineTransform(translationX: -(offset.width + dragState.width), y: -(offset.height + dragState.height))
                        .scaledBy(x: 1 / max(0.001, scale * pinchState), y: 1 / max(0.001, scale * pinchState))
                    let point = CGPoint(x: location.x, y: location.y).applying(inv)
                    let sz = canvasContentSize
                    if let hit = nearestArc(to: point, in: sz) {
                        if selectedArcId == hit.id {
                            showConnectionDetail(for: hit)
                            selectedArcId = nil
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedArcId = hit.id
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedArcId = nil
                        }
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    // Center long press; use same nearest-arc heuristic based on view center
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let inv = CGAffineTransform(translationX: -(offset.width + dragState.width), y: -(offset.height + dragState.height))
                        .scaledBy(x: 1 / max(0.001, scale * pinchState), y: 1 / max(0.001, scale * pinchState))
                    let point = center.applying(inv)
                    let sz = canvasContentSize
                    if let hit = nearestArc(to: point, in: sz) {
                        LibraryService.shared.deleteCrossReference(id: hit.id)
                    }
                }
                .onTapGesture(count: 2) {
                    // Double-tap to zoom in
                    increaseZoom()
                }
                .onHover { isHovering in
                    if !isHovering { hoveredArcId = nil }
                }
                .overlay(alignment: .topLeading) {
                    if let hoveredId = hoveredArcId,
                       let arc = library.crossReferences.first(where: { $0.id == hoveredId }) {
                        HStack(spacing: 8) {
                            Text("\(arc.sourceBookName) \(arc.sourceChapter):\(arc.sourceVerse)")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(arc.targetBookName) \(arc.targetChapter):\(arc.targetVerse)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .position(x: hoverLocation.x, y: hoverLocation.y - 20)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: 8) {
                        Button(action: { shareGraph() }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                                .padding(10)
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        HStack(spacing: 8) {
                            Button(action: { decreaseZoom() }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .foregroundColor(.accentColor)
                                    .padding(10)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button(action: { resetViewTransform() }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.accentColor)
                                    .padding(10)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button(action: { increaseZoom() }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .foregroundColor(.accentColor)
                                    .padding(10)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(12)
                }
            } else {
                // Table view
                List(library.crossReferences, id: \.id) { reference in
                    NavigationLink(destination: CrossReferenceConnectionView(reference: reference)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Origin")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(reference.sourceBookName) \(reference.sourceChapter):\(reference.sourceVerse)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Destination")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(reference.targetBookName) \(reference.targetChapter):\(reference.targetVerse)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            LibraryService.shared.deleteCrossReference(id: reference.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
            }

            HStack {
                Text("Cross References: \(library.crossReferences.count)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Initialize progress for existing arcs to completed
            for line in library.crossReferences { arcProgress[line.id] = 1; arcHeadT[line.id] = 1 }
            // If a focus id was provided, re-animate just that arc with delay for rotation
            if let fid = focusId, let target = library.crossReferences.first(where: { $0.id == fid }) {
                arcProgress[target.id] = 0
                arcHeadT[target.id] = 0
                // Delay for 2.5 seconds to allow user to rotate device
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    // Animate line drawing progressively over 4 seconds
                    withAnimation(.easeInOut(duration: 4.0)) { 
                        arcProgress[target.id] = 1 
                    }
                    // Glow head travels along with the line being drawn (slightly ahead)
                    withAnimation(.easeInOut(duration: 4.2)) { 
                        arcHeadT[target.id] = 1 
                    }
                }
            }
        }
        .onChange(of: library.crossReferences.count) { _, _ in
            let existing = Set(arcProgress.keys)
            let newRefs = library.crossReferences
            let newArcs = newRefs.filter { existing.contains($0.id) == false }
            
            for (index, line) in newArcs.enumerated() {
                arcProgress[line.id] = 0
                arcHeadT[line.id] = 0
                let staggerDelay = 2.5 + Double(index) * 0.015
                
                DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay) {
                    withAnimation(.easeInOut(duration: 4.0)) {
                        arcProgress[line.id] = 1
                    }
                    withAnimation(.easeInOut(duration: 4.2)) {
                        arcHeadT[line.id] = 1
                    }
                }
            }
            
            let ids = Set(newRefs.map { $0.id })
            for key in existing where ids.contains(key) == false {
                arcProgress.removeValue(forKey: key)
                arcHeadT.removeValue(forKey: key)
            }
        }
        .task {
            // Performance optimization: load books only when needed
            if books.isEmpty {
                await loadBooksIfNeeded()
            }
        }
        .navigationTitle(viewMode == .map ? "Cross References" : "Cross References - Table")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Immediate dismissal for better performance - no delay needed
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Bible")
                    }
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.semibold))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // View mode toggle
                    Button(action: { viewMode.toggle() }) {
                        Image(systemName: viewMode == .map ? "list.bullet" : "map")
                            .foregroundColor(.accentColor)
                            .font(.body)
                    }

                    // Seed 100 test data
                    Button(action: { seedTestCrossReferences() }) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.accentColor)
                            .font(.body)
                            .accessibilityLabel("Seed 100 Cross References")
                    }
                    .disabled(isSeeding)

                    // Clear button
                    Button(action: { showClearAlert = true }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.accentColor)
                            .font(.body)
                    }
                    .disabled(library.crossReferences.isEmpty)
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground).opacity(0.95), for: .navigationBar)
        .alert("Clear All Cross References?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllReferences()
            }
        } message: {
            Text("This will permanently delete all \(library.crossReferences.count) cross reference\(library.crossReferences.count == 1 ? "" : "s"). This action cannot be undone.")
        }
        .sheet(isPresented: $showConnectionDetail) {
            if let reference = selectedCrossReference {
                CrossReferenceConnectionView(reference: reference)
            }
        }
        .overlay {
            if isSeeding {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Text("Seeding 100 cross references…")
                            .font(.headline)
                            .foregroundColor(.primary)
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func drawBaseline(in context: GraphicsContext, size: CGSize) {
        let baselineY = size.height - 24
        var path = Path()
        path.move(to: CGPoint(x: 16, y: baselineY))
        path.addLine(to: CGPoint(x: size.width - 16, y: baselineY))
        context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)

        // Chapter ticks: draw a subtle tick for every chapter across all books
        if books.isEmpty == false {
            let leftX: CGFloat = 16
            let rightX: CGFloat = size.width - 16
            let width = rightX - leftX
            var chapterTicks = Path()
            let tickHeight: CGFloat = 8
            for book in books {
                if book.chapters > 0 {
                    for chapter in 1...book.chapters {
                        let nx = normalizedX(bookName: book.name, chapter: chapter)
                        let x = leftX + width * nx
                        chapterTicks.move(to: CGPoint(x: x, y: baselineY))
                        chapterTicks.addLine(to: CGPoint(x: x, y: baselineY - tickHeight))
                    }
                }
            }
            context.stroke(chapterTicks, with: .color(.white.opacity(0.20)), lineWidth: 1)
        }

        // Optional minor tick marks for books if known
        if books.isEmpty == false {
            let slots = CGFloat(books.count)
            for i in 0..<books.count {
                let x = 16 + (size.width - 32) * (CGFloat(i) / max(1, slots - 1))
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: baselineY))
                tick.addLine(to: CGPoint(x: x, y: baselineY + (i % 5 == 0 ? 10 : 6)))
                context.stroke(tick, with: .color(.white.opacity(0.25)), lineWidth: 1)
            }
        }
    }

    private func drawArcs(in context: GraphicsContext, size: CGSize) {
        guard books.isEmpty == false else { return }
        let baselineY = size.height - 24
        let leftX: CGFloat = 16
        let rightX: CGFloat = size.width - 16
        let width = rightX - leftX

        var filtered = library.crossReferences
        
        switch filterScope {
        case .oldTestament:
            filtered = filtered.filter { isOldTestament($0.sourceBookName) && isOldTestament($0.targetBookName) }
        case .newTestament:
            filtered = filtered.filter { isNewTestament($0.sourceBookName) && isNewTestament($0.targetBookName) }
        case .all:
            break
        }
        
        let ordered = filtered.sorted { $0.createdAt < $1.createdAt }
        let limited = densityLimit != nil ? Array(ordered.suffix(densityLimit!)) : ordered
        for line in limited {
            let isSelected = selectedArcId == line.id
            let opacity: Double = selectedArcId == nil ? 1.0 : (isSelected ? 1.0 : 0.25)
            let x1 = leftX + width * normalizedX(bookName: line.sourceBookName, chapter: line.sourceChapter)
            let x2 = leftX + width * normalizedX(bookName: line.targetBookName, chapter: line.targetChapter)
            let midX = (x1 + x2) / 2
            let span = abs(x2 - x1)
            let height = max(40, min(span * 0.6, size.height * 0.9))

            var path = Path()
            path.move(to: CGPoint(x: x1, y: baselineY))
            path.addQuadCurve(to: CGPoint(x: x2, y: baselineY), control: CGPoint(x: midX, y: baselineY - height))

            let sourceColor = colorForBook(line.sourceBookName)
            let targetColor = colorForBook(line.targetBookName)
            
            let adjustedSourceColor = sourceColor.opacity(opacity)
            let adjustedTargetColor = targetColor.opacity(opacity)
            let gradient = Gradient(colors: [adjustedSourceColor, adjustedTargetColor])
            let gradientShading = GraphicsContext.Shading.linearGradient(
                gradient,
                startPoint: CGPoint(x: x1, y: baselineY),
                endPoint: CGPoint(x: x2, y: baselineY)
            )

            // Animation progress for this arc (1 = fully drawn)
            let progress = arcProgress[line.id] ?? 1
            let trimmed = path.trimmedPath(from: 0, to: max(0, min(progress, 1)))
            
            let lineWidth: CGFloat = isSelected ? 2.0 : 1.4

            if progress < 1 || isSelected {
                // Prominent glow while animating (blend source and target colors)
                let sourceIdx = canonicalIndex(for: line.sourceBookName)
                let targetIdx = canonicalIndex(for: line.targetBookName)
                let midHue = (Double(sourceIdx) + Double(targetIdx)) / (2.0 * Double(max(books.count, 1)))
                let glowOpacity = isSelected ? 0.9 : 0.75
                let glowRadius: CGFloat = isSelected ? 16 : 12
                let midColor = Color(hue: midHue, saturation: 0.85, brightness: 0.95, opacity: glowOpacity)
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: midColor, radius: glowRadius, x: 0, y: 0))
                    layer.stroke(trimmed, with: .linearGradient(gradientShading), lineWidth: isSelected ? 4.0 : 3.5)
                }
            }

            context.stroke(trimmed, with: .linearGradient(gradientShading), lineWidth: lineWidth)

            // Moving head glow dot along the curve (travels with line as it's being drawn)
            let headT = min(max(arcHeadT[line.id] ?? progress, 0), 1)
            if headT < 1.0001 && (progress < 0.999 || isCurrentlyLandscape) {
                let point = quadPoint(t: headT, p0: CGPoint(x: x1, y: baselineY), p1: CGPoint(x: midX, y: baselineY - height), p2: CGPoint(x: x2, y: baselineY))
                let sourceIdx = canonicalIndex(for: line.sourceBookName)
                let targetIdx = canonicalIndex(for: line.targetBookName)
                let interpolatedHue = (Double(sourceIdx) * (1 - headT) + Double(targetIdx) * headT) / Double(max(books.count, 1))
                let headColor = Color(hue: interpolatedHue, saturation: 0.85, brightness: 0.95, opacity: 0.9)
                let halo = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: headColor, radius: 16, x: 0, y: 0))
                    layer.fill(halo, with: .color(headColor))
                }
            }
            
            if isSelected {
                let endpointRadius: CGFloat = 4
                let sourceEndpoint = Path(ellipseIn: CGRect(x: x1 - endpointRadius, y: baselineY - endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2))
                let targetEndpoint = Path(ellipseIn: CGRect(x: x2 - endpointRadius, y: baselineY - endpointRadius, width: endpointRadius * 2, height: endpointRadius * 2))
                
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: sourceColor.opacity(0.8), radius: 8, x: 0, y: 0))
                    layer.fill(sourceEndpoint, with: .color(sourceColor))
                }
                
                context.drawLayer { layer in
                    layer.addFilter(.shadow(color: targetColor.opacity(0.8), radius: 8, x: 0, y: 0))
                    layer.fill(targetEndpoint, with: .color(targetColor))
                }
            }

            let hitArea = Path(ellipseIn: CGRect(x: midX - 20, y: baselineY - height/2 - 20, width: 40, height: height + 40))
            context.fill(hitArea, with: .color(Color.clear))
        }
    }

    // MARK: - Gestures
    private func simultaneousGestures() -> some Gesture {
        let magnify = MagnificationGesture()
            .updating($pinchState) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = scale * value
                scale = max(0.5, min(newScale, 6.0))
            }

        let drag = DragGesture(minimumDistance: 2)
            .updating($dragState) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset = CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height)
            }

        return magnify.simultaneously(with: drag)
    }

    private func increaseZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = min(scale * 1.25, 6.0)
        }
    }

    private func decreaseZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = max(scale / 1.25, 0.5)
        }
    }

    private func resetViewTransform() {
        withAnimation(.easeInOut(duration: 0.25)) {
            scale = 1.0
            offset = .zero
        }
    }

    // MARK: - Hit testing helpers
    private func nearestArc(to point: CGPoint, in size: CGSize) -> CrossReferenceLine? {
        // Improved hit-testing: sample along each quadratic and choose the true nearest point
        let baselineY = size.height - 24
        let leftX: CGFloat = 16
        let rightX: CGFloat = size.width - 16
        let width = rightX - leftX

        var bestLine: CrossReferenceLine? = nil
        var bestDistanceSq: CGFloat = .greatestFiniteMagnitude

        // Consider only arcs whose horizontal span is near the tap for better discrimination
        let horizontalPadding: CGFloat = 24

        for line in library.crossReferences {
            let x1 = leftX + width * normalizedX(bookName: line.sourceBookName, chapter: line.sourceChapter)
            let x2 = leftX + width * normalizedX(bookName: line.targetBookName, chapter: line.targetChapter)
            let minX = min(x1, x2) - horizontalPadding
            let maxX = max(x1, x2) + horizontalPadding
            guard point.x >= minX && point.x <= maxX else { continue }

            let midX = (x1 + x2) / 2
            let span = abs(x2 - x1)
            let height = max(40, min(span * 0.6, size.height * 0.9))

            // Sample along the curve to find the closest point
            var localBestSq: CGFloat = .greatestFiniteMagnitude
            var t: CGFloat = 0
            let steps: Int = 24
            for i in 0...steps {
                let tt = CGFloat(i) / CGFloat(steps)
                let p = quadPoint(t: tt,
                                  p0: CGPoint(x: x1, y: baselineY),
                                  p1: CGPoint(x: midX, y: baselineY - height),
                                  p2: CGPoint(x: x2, y: baselineY))
                let dx = p.x - point.x
                let dy = p.y - point.y
                let d2 = dx * dx + dy * dy
                if d2 < localBestSq {
                    localBestSq = d2
                    t = tt
                }
            }

            if localBestSq < bestDistanceSq {
                bestDistanceSq = localBestSq
                bestLine = line
            }
        }

        // Require proximity within a reasonable radius to avoid accidental selections
        let hitRadius: CGFloat = 28
        if bestDistanceSq <= hitRadius * hitRadius {
            return bestLine
        }
        return nil
    }

    private func quadY(t: CGFloat, y0: CGFloat, y1: CGFloat, y2: CGFloat) -> CGFloat {
        let mt = 1 - t
        return mt * mt * y0 + 2 * mt * t * y1 + t * t * y2
    }

    private func quadPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x
        let y = mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
        return CGPoint(x: x, y: y)
    }

    private func colorForBook(_ bookName: String) -> Color {
        let idx = canonicalIndex(for: bookName)
        let totalBooks = max(books.count, 1)
        let hue = Double(idx) / Double(totalBooks)
        return Color(hue: hue, saturation: 0.85, brightness: 0.95, opacity: 0.95)
    }
    
    // Deterministic bright color per connection id (fallback for non-gradient mode)
    private func uniqueColor(for id: UUID) -> Color {
        // Hash UUID into a stable integer seed
        var hasher = Hasher()
        hasher.combine(id)
        let seed = hasher.finalize()
        // Map seed into hue buckets for distinctness, with high saturation/brightness for clarity
        let hueBuckets: [Double] = [
            0.00, 0.08, 0.16, 0.25, 0.33, 0.41, 0.50, 0.58, 0.66, 0.75, 0.83, 0.91
        ]
        let idx = abs(seed) % hueBuckets.count
        let hue = hueBuckets[idx]
        return Color(hue: hue, saturation: 0.88, brightness: 0.95, opacity: 0.95)
    }

    // MARK: - Hover detection
    private func updateHover(at location: CGPoint, in size: CGSize) {
        let inv = CGAffineTransform(translationX: -(offset.width + dragState.width), y: -(offset.height + dragState.height))
            .scaledBy(x: 1 / max(0.001, scale * pinchState), y: 1 / max(0.001, scale * pinchState))
        let point = location.applying(inv)
        
        if let hit = nearestArc(to: point, in: size) {
            hoveredArcId = hit.id
            hoverLocation = location
        } else {
            hoveredArcId = nil
        }
    }

    private func normalizedX(bookName: String, chapter: Int) -> CGFloat {
        let idx = canonicalIndex(for: bookName)
        guard let meta = books.first(where: { $0.name == bookName }) else { return 0 }
        let total = max(1, meta.chapters)
        let chapterFraction = CGFloat(max(0, min(chapter - 1, total - 1))) / CGFloat(total)
        let base = CGFloat(idx)
        let denom = CGFloat(max(books.count - 1, 1))
        return (base + chapterFraction) / denom
    }

    private func canonicalIndex(for bookName: String) -> Int {
        if let match = books.first(where: { $0.name == bookName }) {
            let ordered = books.sorted { a, b in
                BibleService.shared.canonicalOrderIndex(for: a.name) < BibleService.shared.canonicalOrderIndex(for: b.name)
            }
            return ordered.firstIndex(of: match) ?? 0
        }
        return 0
    }
    
    private func isOldTestament(_ bookName: String) -> Bool {
        let otBooks = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi"]
        return otBooks.contains(bookName)
    }
    
    private func isNewTestament(_ bookName: String) -> Bool {
        return !isOldTestament(bookName)
    }

    private func loadBooksIfNeeded() async {
        if books.isEmpty {
            if let loaded = try? await BibleService.shared.fetchBooks() {
                books = loaded.sorted { a, b in
                    BibleService.shared.canonicalOrderIndex(for: a.name) < BibleService.shared.canonicalOrderIndex(for: b.name)
                }
            }
        }
    }

    private func clearAllReferences() {
        let allIds = library.crossReferences.map { $0.id }
        for id in allIds {
            LibraryService.shared.deleteCrossReference(id: id)
        }
        // Clear animation state
        arcProgress.removeAll()
        arcHeadT.removeAll()
    }

    private func showConnectionDetail(for crossReference: CrossReferenceLine) {
        selectedCrossReference = crossReference
        showConnectionDetail = true
    }
    
    @MainActor
    private func shareGraph() {
        let renderer = ImageRenderer(content: 
            GeometryReader { geometry in
                Canvas { context, size in
                    let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: scale, y: scale)
                    context.concatenate(transform)
                    let cachedSize = size.applying(transform.inverted())
                    
                    if !books.isEmpty {
                        drawBaseline(in: context, size: cachedSize)
                        drawArcs(in: context, size: cachedSize)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.black)
            }
            .frame(width: 1200, height: 800)
        )
        
        renderer.scale = 2.0
        
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topVC.view
                    popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                topVC.present(activityVC, animated: true)
            }
        }
    }

    // MARK: - Seed 100 test data (no validation)
    private func seedTestCrossReferences() {
        guard isSeeding == false else { return }
        isSeeding = true
        Task(priority: .userInitiated) {
            let pairs: [(String, String)] = [
                ("2 Timothy 3:16", "Psalm 119:105"),
                ("Isaiah 55:11", "Hebrews 4:12"),
                ("Matthew 4:4", "Deuteronomy 8:3"),
                ("John 17:17", "Psalm 19:7"),
                ("Romans 15:4", "1 Corinthians 10:11"),
                ("Ephesians 2:8–9", "Romans 3:28"),
                ("John 3:16", "Romans 5:8"),
                ("Acts 16:31", "Romans 10:9"),
                ("Titus 3:5", "2 Timothy 1:9"),
                ("1 Peter 1:3", "John 14:6"),
                ("John 13:34–35", "Leviticus 19:18"),
                ("Matthew 22:37–39", "Deuteronomy 6:5"),
                ("Romans 13:10", "Galatians 5:14"),
                ("Colossians 3:14", "1 Corinthians 13:13"),
                ("1 John 4:7", "John 15:12"),
                ("Philippians 4:6–7", "Matthew 6:6"),
                ("1 Thessalonians 5:17", "Luke 18:1"),
                ("James 5:16", "1 John 5:14"),
                ("Psalm 145:18", "Jeremiah 29:12"),
                ("Romans 8:26", "Zechariah 12:10"),
                ("John 14:26", "John 16:13"),
                ("Acts 1:8", "Zechariah 4:6"),
                ("Romans 8:14", "Galatians 5:16"),
                ("1 Corinthians 6:19", "Ezekiel 36:27"),
                ("Galatians 5:22–23", "John 15:5"),
                ("Psalm 23:1", "John 10:11"),
                ("Isaiah 40:31", "Galatians 6:9"),
                ("Philippians 1:6", "Hebrews 12:2"),
                ("Jeremiah 29:11", "Romans 8:28"),
                ("Deuteronomy 31:6", "Hebrews 13:5"),
                ("Genesis 1:1", "John 1:3"),
                ("Colossians 1:16", "Revelation 4:11"),
                ("Nehemiah 9:6", "Psalm 33:6"),
                ("Hebrews 11:3", "Psalm 19:1"),
                ("Romans 1:20", "Isaiah 45:12"),
                ("Genesis 12:2–3", "Galatians 3:8"),
                ("Isaiah 53:5", "1 Peter 2:24"),
                ("Micah 5:2", "Matthew 2:6"),
                ("Psalm 22:16", "John 19:37"),
                ("Zechariah 12:10", "John 19:34"),
                ("Matthew 28:19–20", "Acts 1:8"),
                ("Romans 1:16", "1 Corinthians 1:18"),
                ("2 Corinthians 5:20", "Matthew 5:14–16"),
                ("Acts 20:24", "Philippians 1:21"),
                ("John 20:21", "Luke 24:47"),
                ("Genesis 3:15", "Romans 16:20"),
                ("John 1:29", "Revelation 5:12"),
                ("Hebrews 10:10", "Isaiah 53:10"),
                ("1 Corinthians 15:3–4", "Luke 24:46–47"),
                ("Revelation 12:11", "Romans 8:37"),
                ("Proverbs 3:5–6", "Jeremiah 17:7"),
                ("Psalm 37:4", "Matthew 6:33"),
                ("Isaiah 41:10", "2 Timothy 1:7"),
                ("Joshua 1:9", "Psalm 27:1"),
                ("Romans 8:31", "Psalm 118:6"),
                ("Matthew 6:34", "Philippians 4:6"),
                ("Lamentations 3:22–23", "Psalm 30:5"),
                ("James 1:5", "Proverbs 2:6"),
                ("Proverbs 16:9", "Jeremiah 10:23"),
                ("Ecclesiastes 3:1", "Galatians 6:9"),
                ("Hebrews 13:8", "Malachi 3:6"),
                ("Revelation 1:8", "Isaiah 44:6"),
                ("John 8:58", "Exodus 3:14"),
                ("Colossians 2:9", "John 1:14"),
                ("Philippians 2:10–11", "Isaiah 45:23"),
                ("Psalm 46:1", "Nahum 1:7"),
                ("2 Corinthians 1:3–4", "Matthew 5:4"),
                ("John 14:27", "Philippians 4:7"),
                ("Isaiah 26:3", "Colossians 3:15"),
                ("1 Peter 5:7", "Psalm 55:22"),
                ("Hebrews 4:15", "Isaiah 53:3"),
                ("Matthew 11:28–29", "Jeremiah 31:25"),
                ("Psalm 34:18", "2 Corinthians 12:9"),
                ("John 16:33", "Romans 8:37"),
                ("Romans 6:23", "Ephesians 2:8–9"),
                ("Titus 2:11", "John 1:12"),
                ("Romans 5:1", "Isaiah 32:17"),
                ("Galatians 2:16", "Philippians 3:9"),
                ("John 5:24", "1 John 5:11–12"),
                ("Hebrews 9:28", "Revelation 21:27"),
                ("Matthew 5:14", "Philippians 2:15"),
                ("1 Peter 2:9", "Isaiah 60:1"),
                ("Ephesians 5:8", "2 Corinthians 4:6"),
                ("John 8:12", "Psalm 27:1"),
                ("Colossians 3:16", "Ephesians 5:19"),
                ("Psalm 100:4", "Philippians 4:4"),
                ("Hebrews 12:28", "Psalm 95:6"),
                ("1 Thessalonians 5:18", "Ephesians 5:20"),
                ("Psalm 150:6", "Revelation 5:13"),
                ("Isaiah 12:5", "Exodus 15:1"),
                ("Revelation 22:20", "John 14:3"),
                ("Acts 1:11", "1 Thessalonians 4:16"),
                ("Matthew 24:30", "Revelation 1:7"),
                ("Philippians 3:20", "Hebrews 9:28"),
                ("2 Peter 3:10", "1 Thessalonians 5:2"),
                ("Revelation 21:4", "Isaiah 25:8"),
                ("1 Corinthians 15:52", "1 Thessalonians 4:17"),
                ("Matthew 25:31–32", "Revelation 20:12"),
                ("Daniel 12:2", "John 5:28–29"),
                ("Revelation 22:12", "Romans 14:12")
            ]

            for (from, to) in pairs {
                if let a = parseRef(from), let b = parseRef(to) {
                    let line = CrossReferenceLine(
                        sourceBookId: a.bookId,
                        sourceBookName: a.bookName,
                        sourceChapter: a.chapter,
                        sourceVerse: a.verse,
                        targetBookId: b.bookId,
                        targetBookName: b.bookName,
                        targetChapter: b.chapter,
                        targetVerse: b.verse,
                        note: nil
                    )
                    LibraryService.shared.addCrossReference(line)
                }
            }
            await MainActor.run { isSeeding = false }
        }
    }

    private struct SimpleRef { let bookId: Int; let bookName: String; let chapter: Int; let verse: Int }

    private func parseRef(_ s: String) -> SimpleRef? {
        // Split into tokens; find the part containing ':'
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2013}", with: "-") // en dash → hyphen
        guard let colonIdx = trimmed.firstIndex(of: ":") else { return nil }
        // Backtrack to find where chapter number starts (digit before colon)
        var chapterStart = trimmed.startIndex
        var i = colonIdx
        while i > trimmed.startIndex {
            i = trimmed.index(before: i)
            let ch = trimmed[i]
            if ch == " " { chapterStart = trimmed.index(after: i); break }
        }
        let bookPart = String(trimmed[..<chapterStart]).trimmingCharacters(in: .whitespaces)
        let chapVersePart = String(trimmed[chapterStart...]).trimmingCharacters(in: .whitespaces)
        let parts = chapVersePart.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let chapStr = String(parts[0]).trimmingCharacters(in: .whitespaces)
        var verseStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
        if let dash = verseStr.firstIndex(of: "-") { verseStr = String(verseStr[..<dash]) }
        guard let chapter = Int(chapStr), let verse = Int(verseStr) else { return nil }
        let normalizedBook = normalizeBookName(bookPart)
        guard let bookId = BibleService.shared.canonicalBookId(for: normalizedBook) else { return nil }
        return SimpleRef(bookId: bookId, bookName: normalizedBook, chapter: chapter, verse: verse)
    }

    private func normalizeBookName(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // Normalize common variants
        if s == "Psalm" { return "Psalms" }
        if s.hasPrefix("1John") || s == "1John" { return "1 John" }
        if s.hasPrefix("2John") || s == "2John" { return "2 John" }
        if s.hasPrefix("3John") || s == "3John" { return "3 John" }
        return s
    }

}

// Lightweight wrapper to reduce type inference pressure when used in .sheet
struct CrossRefMapModal: View {
    let focusId: UUID?

    var body: some View {
        NavigationStack {
            CrossReferencesView(focusId: focusId)
        }
    }
}

// MARK: - Connection Detail Sheet
struct CrossReferenceConnectionView: View {
    let reference: CrossReferenceLine
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bibleRouter: BibleRouter
    @State private var originVerse: BibleVerse?
    @State private var destinationVerse: BibleVerse?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.accentColor)

                        Text("Cross Reference")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        // Connection summary
                        HStack(spacing: 16) {
                            Text("\(reference.sourceBookName) \(reference.sourceChapter):\(reference.sourceVerse)")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)

                            Text("\(reference.targetBookName) \(reference.targetChapter):\(reference.targetVerse)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    // Side by side verses
                    HStack(alignment: .top, spacing: 20) {
                        // Origin verse
                        VStack(alignment: .leading, spacing: 12) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.semibold)

                            if let verse = originVerse {
                                Text("\(reference.sourceBookName) \(reference.sourceChapter):\(reference.sourceVerse)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(verse.text)
                                    .font(.system(size: 17, weight: .regular, design: .serif))
                                    .foregroundColor(.primary)
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.secondary)
                            } else {
                                Text("Verse not found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Divider
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1)

                        // Destination verse
                        VStack(alignment: .leading, spacing: 12) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.semibold)

                            if let verse = destinationVerse {
                                Text("\(reference.targetBookName) \(reference.targetChapter):\(reference.targetVerse)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(verse.text)
                                    .font(.system(size: 17, weight: .regular, design: .serif))
                                    .foregroundColor(.primary)
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.secondary)
                            } else {
                                Text("Verse not found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)

                    // No navigation buttons; popup-only per request
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadVerses()
        }
    }

    private func loadVerses() async {
        isLoading = true

        // Load origin verse
        do {
            let originVerses = try await BibleService.shared.fetchVerses(
                bookId: getBookId(for: reference.sourceBookName),
                chapter: reference.sourceChapter
            )
            originVerse = originVerses.first(where: { $0.verse == reference.sourceVerse })
        } catch {
            print("Failed to load origin verse: \(error)")
        }

        // Load destination verse
        do {
            let destVerses = try await BibleService.shared.fetchVerses(
                bookId: getBookId(for: reference.targetBookName),
                chapter: reference.targetChapter
            )
            destinationVerse = destVerses.first(where: { $0.verse == reference.targetVerse })
        } catch {
            print("Failed to load destination verse: \(error)")
        }

        isLoading = false
    }

    private func navigateToSource() {
        // Immediate dismissal and navigation for better performance
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Reduced delay
            Task {
                let bookId = self.getBookId(for: self.reference.sourceBookName)
                if let books = try? await BibleService.shared.fetchBooks(),
                   let book = books.first(where: { $0.id == bookId }) {
                    self.bibleRouter.goToChapter(book: book, chapter: self.reference.sourceChapter)
                }
            }
        }
    }

    private func navigateToTarget() {
        // Immediate dismissal and navigation for better performance
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Reduced delay
            Task {
                let bookId = self.getBookId(for: self.reference.targetBookName)
                if let books = try? await BibleService.shared.fetchBooks(),
                   let book = books.first(where: { $0.id == bookId }) {
                    self.bibleRouter.goToChapter(book: book, chapter: self.reference.targetChapter)
                }
            }
        }
    }

    private func getBookId(for bookName: String) -> Int {
        return BibleService.shared.canonicalBookId(for: bookName) ?? 1
    }
}
