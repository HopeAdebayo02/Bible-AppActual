import Foundation
import Combine

final class TranslationService: ObservableObject {
    static let shared = TranslationService()

    // Persisted selected version (e.g., "BSB", "ESV", "NLT", "WEB", "KJV")
    @Published var version: String {
        didSet { UserDefaults.standard.set(version, forKey: storageKey) }
    }

    let available: [String] = ["BSB", "ESV", "NLT", "WEB", "KJV"]
    private let storageKey = "settings.translation.version"

    private init() {
        let saved = UserDefaults.standard.string(forKey: storageKey)
        self.version = saved ?? "BSB"
    }

    // MARK: - Reset
    func reset() {
        version = "BSB"
    }
}



