import Foundation
import Testing
@testable import Lucius

struct VocabularyAnalyticsTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 UTC

    @Test func computesOverviewWeakWordsAndLearningSpeed() {
        let words = [
            VocabularyWord(
                word: "mastered",
                translation: "m",
                languageCode: "en",
                reviewStatus: .mastered,
                nextReviewDate: now.addingTimeInterval(86_400),
                createdAt: now.addingTimeInterval(-4 * 86_400),
                updatedAt: now,
                mistakeCount: 2,
                successfulReviewCount: 3,
                firstMasteredAt: now
            ),
            VocabularyWord(
                word: "familiar",
                translation: "f",
                languageCode: "en",
                reviewStatus: .familiar,
                nextReviewDate: now
            ),
            VocabularyWord(
                word: "new",
                translation: "n",
                languageCode: "en",
                reviewStatus: .new
            ),
            VocabularyWord(word: "bonjour", translation: "hello", languageCode: "fr"),
        ]

        let snapshot = VocabularyAnalyticsEngine.makeSnapshot(
            words: words,
            reviewEvents: [],
            languageCode: "en",
            now: now,
            calendar: calendar
        )

        #expect(snapshot.overview.total == 3)
        #expect(snapshot.overview.learned == 2)
        #expect(snapshot.overview.new == 1)
        #expect(snapshot.overview.forgotten == 1)
        #expect(snapshot.overview.dueToday == 1)
        #expect(snapshot.mostForgottenWords.first?.word == "mastered")
        #expect(snapshot.averageMemorizationDays == 4)
        #expect(snapshot.averageSuccessfulReviewsToMastery == 3)
    }

    @Test func computesReviewAccuracyAndContinuingStreak() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let events = [
            ReviewEvent(date: yesterday, wasCorrect: true, languageCode: "en"),
            ReviewEvent(date: twoDaysAgo, wasCorrect: true, languageCode: "en"),
            ReviewEvent(date: twoDaysAgo, wasCorrect: false, languageCode: "en"),
        ]

        let snapshot = VocabularyAnalyticsEngine.makeSnapshot(
            words: [],
            reviewEvents: events,
            languageCode: "en",
            now: now,
            calendar: calendar
        )

        #expect(snapshot.streak == 2)
        #expect(abs(snapshot.reviewAccuracy - (2.0 / 3.0)) < 0.001)
        #expect(snapshot.totalReviews == 3)
    }

    @Test func hidesCefrWithoutDictionaryAndComputesItWhenAvailable() {
        let words = [
            VocabularyWord(word: "door", translation: "d", languageCode: "en"),
            VocabularyWord(word: "withstand", translation: "w", languageCode: "en"),
        ]

        let unavailable = VocabularyAnalyticsEngine.makeSnapshot(
            words: words,
            reviewEvents: [],
            languageCode: "en",
            cefrLookup: nil,
            now: now,
            calendar: calendar
        )
        let available = VocabularyAnalyticsEngine.makeSnapshot(
            words: words,
            reviewEvents: [],
            languageCode: "en",
            cefrLookup: ["door": .a1, "withstand": .c1],
            now: now,
            calendar: calendar
        )

        #expect(unavailable.cefrDistribution == nil)
        #expect(available.cefrDistribution?.first(where: { $0.level == .a1 })?.count == 1)
        #expect(available.cefrDistribution?.first(where: { $0.level == .c1 })?.percentage == 0.5)
    }
}
