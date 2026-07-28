import Foundation
import SwiftData
import WidgetKit

/// Keeps the widget's shared snapshot in step with the database.
/// Call `update` after any change that affects due counts or the streak.
enum WidgetSync {
    @MainActor
    static func update(context: ModelContext) {
        let fetchedWords = (try? context.fetch(FetchDescriptor<VocabularyWord>())) ?? []
        let languageCode = AppLanguageSettings.learningLanguageCode
        let words = fetchedWords.filter { $0.languageCode == languageCode }
        let events = (try? context.fetch(FetchDescriptor<ReviewEvent>())) ?? []

        let stats = HomeViewModel.stats(for: words)
        let summary = HomeViewModel.activitySummary(reviewDates: events.map(\.date))

        let snapshot = ReviewSnapshot(
            reviewDates: words.compactMap(\.nextReviewDate),
            streak: summary.streak,
            totalWords: stats.total,
            masteredCount: stats.mastered
        )

        SharedStore.save(snapshot)

        let smartWords = words.map {
            SharedVocabularyWord(
                id: $0.id,
                word: $0.word,
                translation: $0.translation,
                languageCode: $0.languageCode,
                reviewStatus: $0.reviewStatus.rawValue,
                difficulty: $0.difficulty.rawValue,
                nextReviewDate: $0.nextReviewDate,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt,
                mistakeCount: $0.mistakeCount,
                successfulReviewCount: $0.successfulReviewCount,
                category: nil
            )
        }
        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let previous = SharedStore.loadSmartWord()
        let previousWord = previous.selectedWordID.flatMap { id in
            previous.words.first { $0.id == id }
        }
        let currentPreviousWord = previous.selectedWordID.flatMap { id in
            smartWords.first { $0.id == id }
        }
        let sameDay = previous.selectionDay.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        let wasReviewed = previousWord.map { oldWord in
            guard let currentPreviousWord else { return true }
            return oldWord.reviewStatus != currentPreviousWord.reviewStatus
                || oldWord.nextReviewDate != currentPreviousWord.nextReviewDate
                || oldWord.mistakeCount != currentPreviousWord.mistakeCount
                || oldWord.successfulReviewCount != currentPreviousWord.successfulReviewCount
        } ?? true
        let shouldPreserve = sameDay && currentPreviousWord != nil && !wasReviewed
        let selectedWord: SharedVocabularyWord?
        if shouldPreserve {
            selectedWord = currentPreviousWord
        } else {
            let candidates = wasReviewed
                ? smartWords.filter { $0.id != previous.selectedWordID }
                : smartWords
            selectedWord = SmartWordSelection.select(
                from: candidates.isEmpty ? smartWords : candidates,
                now: now,
                calendar: calendar,
                languageCode: languageCode
            )
        }

        let copy = SmartWordCopy(
            title: String(localized: "smart_word.title"),
            tapToReview: String(localized: "smart_word.tap_to_review"),
            emptyMessage: String(localized: "smart_word.empty_message")
        )
        let smartWordChanged = previous.words != smartWords
            || previous.selectedWordID != selectedWord?.id
            || previous.selectionDay.map { !calendar.isDate($0, inSameDayAs: today) } ?? true
            || previous.copy != copy
        let smartSnapshot = SmartWordSnapshot(
            words: smartWords,
            updatedAt: smartWordChanged ? now : previous.updatedAt,
            interfaceLanguageCode: Locale.current.identifier,
            copy: copy,
            selectedWordID: selectedWord?.id,
            selectionDay: today
        )
        SharedStore.saveSmartWord(smartSnapshot)

        // Reload only the widgets backed by this local snapshot. This keeps
        // unrelated widget families from being invalidated on every review.
        WidgetCenter.shared.reloadTimelines(ofKind: "LuciusReviewWidget")
        if smartWordChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "LuciusSmartWordWidget")
        }
    }
}
