import Foundation

@MainActor
enum LocalData {
    static func resetForSignOut() {
        LibraryService.shared.reset()
        HighlightService.shared.reset()
        ReadingTrackerService.shared.reset()
        VerseOfTheDayService.shared.reset()
        TranslationService.shared.reset()
        AppearanceService.shared.reset()
    }

    static func resetForUserSwitch() {
        resetForSignOut()
    }

    static func fetchRemoteForCurrentUser() async {
        // Placeholder for future remote sync; for now reload local views
        LibraryService.shared.reset()
        HighlightService.shared.reset()
        ReadingTrackerService.shared.reset()
        VerseOfTheDayService.shared.reset()
        TranslationService.shared.reset()
        AppearanceService.shared.reset()
    }
}


