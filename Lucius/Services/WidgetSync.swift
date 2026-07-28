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

        let previousReviewSnapshot = SharedStore.load()
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
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let now = Date.now
        let calendar = Calendar.current
        let previous = SharedStore.loadSmartWord()
        let copy = SmartWordCopy(
            title: String(localized: "smart_word.title"),
            tapToReview: String(localized: "smart_word.tap_to_review"),
            emptyMessage: String(localized: "smart_word.empty_message")
        )
        let smartSnapshot = SmartWordSnapshotResolver.updating(
            previous: previous,
            words: smartWords,
            interfaceLanguageCode: Locale.current.identifier,
            copy: copy,
            now: now,
            calendar: calendar
        )
        let smartWordChanged = smartSnapshot != previous
        SharedStore.saveSmartWord(smartSnapshot)

        // Reload only the widgets backed by this local snapshot. This keeps
        // unrelated widget families from being invalidated on every review.
        if snapshot != previousReviewSnapshot {
            WidgetCenter.shared.reloadTimelines(ofKind: "LuciusReviewWidget")
        }
        if smartWordChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "LuciusSmartWordWidget")
        }
    }
}
