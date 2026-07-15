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
        WidgetCenter.shared.reloadAllTimelines()
    }
}
