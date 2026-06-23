import Testing
import Foundation
@testable import Lucius

struct ReviewSchedulerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func interval(_ word: VocabularyWord) -> TimeInterval {
        (word.nextReviewDate ?? now).timeIntervalSince(now)
    }

    // MARK: - First review delay

    @Test func firstReviewDelayMatchesDifficulty() {
        #expect(ReviewScheduler.firstReviewDate(for: .easy, from: now).timeIntervalSince(now) == 24 * 60 * 60)
        #expect(ReviewScheduler.firstReviewDate(for: .medium, from: now).timeIntervalSince(now) == 6 * 60 * 60)
        #expect(ReviewScheduler.firstReviewDate(for: .hard, from: now).timeIntervalSince(now) == 30 * 60)
    }

    // MARK: - Answer transitions

    @Test func forgotResetsToLearningInThirtyMinutes() {
        let word = VocabularyWord(word: "w", translation: "t", reviewStatus: .familiar)
        let outcome = ReviewScheduler.apply(.forgot, to: word, now: now)

        #expect(word.reviewStatus == .learning)
        #expect(interval(word) == 30 * 60)
        #expect(outcome.didReachMastered == false)
    }

    @Test func almostAdvancesToFamiliarInOneDay() {
        let word = VocabularyWord(word: "w", translation: "t", reviewStatus: .new)
        let outcome = ReviewScheduler.apply(.almost, to: word, now: now)

        #expect(word.reviewStatus == .familiar)
        #expect(interval(word) == 24 * 60 * 60)
        #expect(outcome.didReachMastered == false)
    }

    @Test func knowItFromNewBecomesFamiliarInSevenDays() {
        let word = VocabularyWord(word: "w", translation: "t", reviewStatus: .new)
        let outcome = ReviewScheduler.apply(.knowIt, to: word, now: now)

        #expect(word.reviewStatus == .familiar)
        #expect(interval(word) == 7 * 24 * 60 * 60)
        #expect(outcome.didReachMastered == false)
    }

    @Test func knowItFromFamiliarMastersInThirtyDays() {
        let word = VocabularyWord(word: "w", translation: "t", reviewStatus: .familiar)
        let outcome = ReviewScheduler.apply(.knowIt, to: word, now: now)

        #expect(word.reviewStatus == .mastered)
        #expect(interval(word) == 30 * 24 * 60 * 60)
        #expect(outcome.didReachMastered == true)
    }

    @Test func knowItOnAlreadyMasteredDoesNotReCelebrate() {
        let word = VocabularyWord(word: "w", translation: "t", reviewStatus: .mastered)
        let outcome = ReviewScheduler.apply(.knowIt, to: word, now: now)

        #expect(word.reviewStatus == .mastered)
        #expect(outcome.didReachMastered == false)
    }

    @Test func applyStampsUpdatedAt() {
        let word = VocabularyWord(word: "w", translation: "t")
        ReviewScheduler.apply(.almost, to: word, now: now)
        #expect(word.updatedAt == now)
    }
}
