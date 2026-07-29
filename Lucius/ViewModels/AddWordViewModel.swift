import Foundation
import SwiftData

/// Form state and saving logic for adding a new word.
@Observable
@MainActor
final class AddWordViewModel {
    enum SourceKind: String, CaseIterable, Identifiable {
        case book, movie, podcast, article, website, other
        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .book: String(localized: "word.flow.source.book")
            case .movie: String(localized: "word.flow.source.movie")
            case .podcast: String(localized: "word.flow.source.podcast")
            case .article: String(localized: "word.flow.source.article")
            case .website: String(localized: "word.flow.source.website")
            case .other: String(localized: "word.flow.source.other")
            }
        }
    }

    var word = ""
    var translation = ""
    var example = ""
    var visualAssociation = ""
    var bookTitle = ""
    var chapter = ""
    var difficulty: WordDifficulty = .medium
    var sourceKind: SourceKind?
    var shouldGenerateScene = false
    private(set) var isTranslating = false
    private(set) var translationFailed = false
    let languageCode = AppLanguageSettings.learningLanguageCode

    var canSave: Bool {
        !trimmed(word).isEmpty && !trimmed(translation).isEmpty
    }

    func applyScannedText(_ text: String) {
        word = normalizedScannedText(text)
    }

    func applyScannedContext(_ text: String) {
        example = normalizedScannedText(text)
    }

    func wordDidChange() {
        isTranslating = false
        translationFailed = false
        translation = ""
    }

    @discardableResult
    func translateAutomatically(expectedWord: String) async -> Bool {
        let cleaned = trimmed(expectedWord)
        guard !cleaned.isEmpty, cleaned == trimmed(word) else { return false }
        isTranslating = true
        translationFailed = false
        defer { isTranslating = false }

        do {
            let result = try await TranslationService.shared.translate(cleaned)
            guard cleaned == trimmed(word), !Task.isCancelled else { return false }
            translation = result
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard cleaned == trimmed(word) else { return false }
            translationFailed = true
            return false
        }
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
            languageCode: languageCode,
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
        WidgetSync.update(context: context, forceSmartWordReload: true)
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
