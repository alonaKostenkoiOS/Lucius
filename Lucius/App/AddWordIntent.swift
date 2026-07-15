import AppIntents
import SwiftData

/// Lets users add a word to Lucius from Siri, Spotlight or the Shortcuts app —
/// e.g. "Add serendipity to Lucius". Runs without bringing the app to the front.
struct AddWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Word"
    static let description = IntentDescription("Add a new word to your Lucius vocabulary.")
    static let openAppWhenRun = false

    @Parameter(title: "Word", requestValueDialog: "Which word would you like to add?")
    var word: String

    @Parameter(title: "Translation")
    var translation: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else {
            return .result(dialog: "I couldn't add an empty word.")
        }

        let context = ModelContainerFactory.make().mainContext
        let newWord = VocabularyWord(
            word: trimmedWord,
            translation: (translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            languageCode: AppLanguageSettings.learningLanguageCode,
            difficulty: .medium,
            nextReviewDate: ReviewScheduler.firstReviewDate(for: .medium)
        )
        context.insert(newWord)
        try context.save()

        NotificationService.shared.scheduleReviewNotification(for: newWord)
        WidgetSync.update(context: context)

        return .result(dialog: "Added “\(trimmedWord)” to Lucius.")
    }
}

/// Exposes the intent to Siri and the Shortcuts gallery with spoken phrases.
struct LuciusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWordIntent(),
            phrases: [
                "Add a word to \(.applicationName)",
                "Add a new word in \(.applicationName)",
                "Save a word to \(.applicationName)",
            ],
            shortTitle: "Add Word",
            systemImageName: "plus.circle"
        )
    }
}
