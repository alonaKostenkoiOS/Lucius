import Testing
import Foundation
@testable import Lucius

@MainActor
struct HomeViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let calendar = Calendar(identifier: .gregorian)

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    // MARK: - Stats

    @Test func computesWordStats() {
        let words = [
            VocabularyWord(word: "a", translation: "x", reviewStatus: .mastered, nextReviewDate: .distantFuture),
            VocabularyWord(word: "b", translation: "y", reviewStatus: .new, nextReviewDate: .distantPast),
            VocabularyWord(word: "c", translation: "z", reviewStatus: .learning, nextReviewDate: .distantPast),
        ]

        let stats = HomeViewModel.stats(for: words)
        #expect(stats.total == 3)
        #expect(stats.mastered == 1)
        #expect(stats.due == 2)
    }

    @Test func masteryFractionIsZeroWithNoWords() {
        let viewModel = HomeViewModel()
        #expect(viewModel.masteryFraction == 0)
    }

    // MARK: - Activity & streak

    @Test func activityHasOneCellPerDay() {
        let summary = HomeViewModel.activitySummary(reviewDates: [], now: now, calendar: calendar)
        #expect(summary.activity.count == HomeViewModel.heatmapDays)
        #expect(summary.activity.allSatisfy { $0.count == 0 })
        #expect(summary.streak == 0)
    }

    @Test func countsStreakOfConsecutiveDays() {
        // Today and yesterday active, gap, then day -3 active.
        let dates = [now, daysAgo(1), daysAgo(3)]
        let summary = HomeViewModel.activitySummary(reviewDates: dates, now: now, calendar: calendar)
        #expect(summary.streak == 2)
    }

    @Test func streakIsZeroWhenNothingReviewedToday() {
        let summary = HomeViewModel.activitySummary(reviewDates: [daysAgo(1)], now: now, calendar: calendar)
        #expect(summary.streak == 0)
    }

    @Test func activityBucketsReviewsByDay() {
        let dates = [now, now, daysAgo(2)]
        let summary = HomeViewModel.activitySummary(reviewDates: dates, now: now, calendar: calendar)

        let today = calendar.startOfDay(for: now)
        let todayCell = summary.activity.first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(todayCell?.count == 2)
    }
}
