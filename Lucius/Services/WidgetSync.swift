import Foundation
import SwiftData
import WidgetKit

/// Keeps the widget's shared snapshot in step with the database.
/// Call `update` after any change that affects due counts or the streak.
enum WidgetSync {
    @MainActor
    static func update(context: ModelContext, forceSmartWordReload: Bool = false) {
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

        let now = Date.now
        let calendar = Calendar.current
        let candidates = words.map {
            WidgetWordSnapshot(
                id: $0.id,
                word: $0.word,
                shortTranslation: shortTranslation($0.translation),
                reviewPriority: priority(for: $0, now: now),
                lastUpdated: $0.updatedAt
            )
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let previous = SharedStore.loadSmartWord()
        let smartPayload = SmartWordPayloadResolver.update(
            previous: previous,
            candidates: candidates,
            now: now,
            calendar: calendar
        )
        let smartWordChanged = smartPayload != previous
        SharedStore.saveSmartWord(smartPayload)

        // Reload only the widgets backed by this local snapshot. This keeps
        // unrelated widget families from being invalidated on every review.
        if snapshot != previousReviewSnapshot {
            WidgetCenter.shared.reloadTimelines(ofKind: "LuciusReviewWidget")
        }
        if smartWordChanged || forceSmartWordReload {
            WidgetCenter.shared.reloadTimelines(ofKind: "LuciusSmartWordWidget")
        }
    }

    static func priority(for word: VocabularyWord, now: Date) -> WidgetReviewPriority {
        if word.nextReviewDate.map({ $0 <= now }) == true { return .overdue }
        if word.difficulty == .hard || word.mistakeCount > 0 { return .difficult }
        if word.reviewStatus == .learning { return .learning }
        if word.reviewStatus == .mastered { return .mastered }
        return .recent
    }

    static func shortTranslation(_ translation: String) -> String {
        let normalized = translation
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(normalized.prefix(160))
    }
}
