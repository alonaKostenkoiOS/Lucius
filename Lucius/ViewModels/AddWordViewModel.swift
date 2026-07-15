import Foundation
import SwiftData

/// Form state and saving logic for adding a new word.
@Observable
@MainActor
final class AddWordViewModel {
    var word = ""
    var translation = ""
    var example = ""
    var visualAssociation = ""
    var bookTitle = ""
    var chapter = ""
    var difficulty: WordDifficulty = .medium

    var canSave: Bool {
        !trimmed(word).isEmpty && !trimmed(translation).isEmpty
    }

    func applyScannedText(_ text: String) {
        word = normalizedScannedText(text)
    }

    func applyScannedContext(_ text: String) {
        example = normalizedScannedText(text)
    }

    private func normalizedScannedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Saves the word, schedules its first review and a local reminder.
    /// Returns the saved word so the caller can dismiss / navigate.
    @discardableResult
    func save(context: ModelContext) -> VocabularyWord? {
        guard canSave else { return nil }

        let newWord = VocabularyWord(
            word: trimmed(word),
            translation: trimmed(translation),
            example: optionalValue(example),
            visualAssociation: optionalValue(visualAssociation),
            bookTitle: optionalValue(bookTitle),
            chapter: optionalValue(chapter),
            difficulty: difficulty,
            nextReviewDate: ReviewScheduler.firstReviewDate(for: difficulty)
        )

        context.insert(newWord)
        try? context.save()

        NotificationService.shared.scheduleReviewNotification(for: newWord)
        WidgetSync.update(context: context)
        return newWord
    }

    // MARK: - Helpers

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Empty strings become nil so optional fields stay truly optional.
    private func optionalValue(_ value: String) -> String? {
        let cleaned = trimmed(value)
        return cleaned.isEmpty ? nil : cleaned
    }
}
