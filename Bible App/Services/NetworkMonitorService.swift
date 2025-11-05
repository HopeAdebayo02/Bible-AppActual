import Foundation
import Network
import SwiftUI

// MARK: - Network Status
enum NetworkStatus {
    case connected
    case disconnected
    case connecting
    case unknown
    
    var isConnected: Bool {
        return self == .connected
    }
}

// MARK: - Network Monitor Service
@MainActor
class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()
    
    @Published var status: NetworkStatus = .unknown
    @Published var isExpensive: Bool = false
    @Published var isConstrained: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkStatus(_ path: NWPath) {
        switch path.status {
        case .satisfied:
            status = .connected
        case .unsatisfied:
            status = .disconnected
        case .requiresConnection:
            status = .connecting
        @unknown default:
            status = .unknown
        }
        
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Network-Aware Bible Service Extension
extension BibleService {
    
    // Network-aware verse fetching
    func fetchVersesWithNetworkCheck(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        // Always try cache first
        if let cachedVerses = BibleCacheService.shared.getCachedVerses(
            bookId: bookId, 
            chapter: chapter, 
            version: await TranslationService.shared.version.uppercased()
        ) {
            return cachedVerses
        }
        
        // Check network status before making API calls
        let networkStatus = await NetworkMonitorService.shared.status
        let isExpensive = await NetworkMonitorService.shared.isExpensive
        let isConstrained = await NetworkMonitorService.shared.isConstrained
        
        guard networkStatus.isConnected else {
            throw NSError(domain: "NetworkMonitorService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "No internet connection available"
            ])
        }
        
        // Warn about expensive connections
        if isExpensive {
            print("Warning: Using cellular data for Bible content")
        }
        
        // Use constrained mode for limited connections
        if isConstrained {
            return try await fetchVersesConstrainedMode(bookId: bookId, chapter: chapter)
        }
        
        // Normal fetch with caching
        return try await fetchVersesWithCache(bookId: bookId, chapter: chapter)
    }
    
    // Constrained mode - prefer cached/local sources
    func fetchVersesConstrainedMode(bookId: Int, chapter: Int) async throws -> [BibleVerse] {
        let selectedVersion = await TranslationService.shared.version.uppercased()
        
        // In constrained mode, prefer local sources (Supabase) over external APIs
        switch selectedVersion {
        case "BSB", "WEB":
            // These are likely in Supabase, try them first
            let verses = try await fetchVerses(bookId: bookId, chapter: chapter, version: selectedVersion)
            if !verses.isEmpty {
                return verses
            }
        default:
            // For other versions, still try normal fetch but with shorter timeouts
            break
        }
        
        // Fallback to normal fetch
        return try await fetchVerses(bookId: bookId, chapter: chapter)
    }
}

// MARK: - Network Status View Modifier
struct NetworkStatusModifier: ViewModifier {
    @StateObject private var networkMonitor = NetworkMonitorService.shared
    @State private var showNetworkAlert = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if networkMonitor.status == .disconnected {
                    networkStatusBanner
                }
            }
            .onChange(of: networkMonitor.status) { oldStatus, newStatus in
                if oldStatus == .connected && newStatus == .disconnected {
                    showNetworkAlert = true
                }
            }
            .alert("No Internet Connection", isPresented: $showNetworkAlert) {
                Button("OK") { }
            } message: {
                Text("Some features may not work without an internet connection. Cached content will still be available.")
            }
    }
    
    @ViewBuilder
    private var networkStatusBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            Text("No Internet Connection")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red)
        .transition(.move(edge: .top))
    }
}

extension View {
    func networkStatusMonitoring() -> some View {
        modifier(NetworkStatusModifier())
    }
}

// MARK: - Smart Preloading Based on Network Status
extension BibleCachePreloader {
    
    func smartPreload() {
        Task { @MainActor in
            let networkMonitor = NetworkMonitorService.shared
            let status = networkMonitor.status
            let isExpensive = networkMonitor.isExpensive
            let isConstrained = networkMonitor.isConstrained
            
            guard status.isConnected else {
                print("Skipping preload - no network connection")
                return
            }
            
            if isExpensive {
                // On cellular, only preload essential chapters
                preloadEssentialChapters()
            } else if isConstrained {
                // On constrained networks, preload less aggressively
                preloadLimitedChapters()
            } else {
                // On good connections, preload normally
                preloadPopularChapters()
            }
        }
    }
    
    func preloadEssentialChapters() {
        preloadQueue.async {
            let essentialChapters: [(bookId: Int, chapter: Int)] = [
                (19, 23), // Psalm 23
                (43, 3),  // John 3
            ]
            
            Task {
                for (bookId, chapter) in essentialChapters {
                    do {
                        let _ = try await BibleService.shared.fetchVersesWithCache(
                            bookId: bookId, 
                            chapter: chapter
                        )
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    } catch {
                        print("Failed to preload essential \(bookId):\(chapter) - \(error)")
                    }
                }
            }
        }
    }
    
    func preloadLimitedChapters() {
        preloadQueue.async {
            let limitedChapters: [(bookId: Int, chapter: Int)] = [
                (1, 1),   // Genesis 1
                (19, 23), // Psalm 23
                (43, 3),  // John 3
            ]
            
            Task {
                for (bookId, chapter) in limitedChapters {
                    do {
                        let _ = try await BibleService.shared.fetchVersesWithCache(
                            bookId: bookId, 
                            chapter: chapter
                        )
                        try await Task.sleep(nanoseconds: 750_000_000) // 0.75 seconds delay
                    } catch {
                        print("Failed to preload limited \(bookId):\(chapter) - \(error)")
                    }
                }
            }
        }
    }
}
