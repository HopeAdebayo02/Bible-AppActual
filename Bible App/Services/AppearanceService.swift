import Foundation
import Combine

final class AppearanceService: ObservableObject {
    static let shared = AppearanceService()

    @Published var isDarkMode: Bool
    private let key = "appearance.isDarkMode"

    private init() {
        isDarkMode = UserDefaults.standard.bool(forKey: key)
    }

    func toggle() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: key)
        objectWillChange.send()
    }

    // MARK: - Reset
    func reset() {
        isDarkMode = false
        UserDefaults.standard.set(isDarkMode, forKey: key)
        objectWillChange.send()
    }
}


