import Foundation
import SwiftData

/// Stats, the recent-words list, and learning-activity data for the home screen.
@Observable
@MainActor
final class HomeViewModel {
    private(set) var totalWordsCount = 0
    private(set) var dueTodayCount = 0
    private(set) var masteredCount = 0
    private(set) var recentWords: [VocabularyWord] = []

    /// Reviews per day for the last `heatmapDays`, oldest first — drives the heatmap.
    private(set) var activity: [DayActivity] = []
    /// Consecutive days up to today with at least one review.
    private(set) var streak = 0

    private static let recentWordsLimit = 5
    static let heatmapDays = 91 // ~13 weeks

    struct DayActivity: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    /// Share of words that have reached mastered — fills the progress ring.
    var masteryFraction: Double {
        guard totalWordsCount > 0 else { return 0 }
        return Double(masteredCount) / Double(totalWordsCount)
    }

    func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<VocabularyWord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let allWords = (try? context.fetch(descriptor)) ?? []

        let stats = Self.stats(for: allWords)
        totalWordsCount = stats.total
        dueTodayCount = stats.due
        masteredCount = stats.mastered
        recentWords = Array(allWords.prefix(Self.recentWordsLimit))

        let events = (try? context.fetch(FetchDescriptor<ReviewEvent>())) ?? []
        let summary = Self.activitySummary(reviewDates: events.map(\.date))
        activity = summary.activity
        streak = summary.streak
    }

    // MARK: - Pure computation (unit-tested without SwiftData)

    struct Stats {
        let total: Int
        let due: Int
        let mastered: Int
    }

    static func stats(for words: [VocabularyWord]) -> Stats {
        Stats(
            total: words.count,
            due: words.count(where: \.isDueForReview),
            mastered: words.count { $0.reviewStatus == .mastered }
        )
    }

    /// Builds the heatmap days (oldest→newest, ending today) and the current
    /// consecutive-day streak from a set of review timestamps.
    static func activitySummary(
        reviewDates: [Date],
        days: Int = heatmapDays,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (activity: [DayActivity], streak: Int) {
        let today = calendar.startOfDay(for: now)

        // Count reviews per calendar day.
        var counts: [Date: Int] = [:]
        for date in reviewDates {
            counts[calendar.startOfDay(for: date), default: 0] += 1
        }

        let activity: [DayActivity] = (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayActivity(date: day, count: counts[day] ?? 0)
        }

        // Streak: walk back from today while each day has activity.
        var streak = 0
        var cursor = today
        while (counts[cursor] ?? 0) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return (activity, streak)
    }
}
