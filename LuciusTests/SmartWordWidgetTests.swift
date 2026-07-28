import Foundation
import XCTest
@testable import Lucius

/// Tests for the pure data and selection rules shared by the app and the
/// Smart Word Widget extension.  Keeping these tests independent of WidgetKit
/// makes them deterministic and runnable in the normal Lucius test target.
final class SmartWordWidgetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testPriorityIsOverdueThenDifficultThenLearningThenRecent() {
        let words = [
            make("recent", status: "new", createdAt: now.addingTimeInterval(40)),
            make("learning", status: "learning", createdAt: now.addingTimeInterval(30)),
            make("difficult", status: "familiar", createdAt: now.addingTimeInterval(20), mistakes: 2),
            make("overdue", status: "familiar", nextReviewDate: now.addingTimeInterval(-60), createdAt: now)
        ]

        XCTAssertEqual(
            SmartWordSelection.select(from: words, now: now, calendar: calendar)?.word,
            "overdue"
        )

        let withoutOverdue = words.filter { $0.word != "overdue" }
        XCTAssertEqual(
            SmartWordSelection.select(from: withoutOverdue, now: now, calendar: calendar)?.word,
            "difficult"
        )

        let withoutDifficult = withoutOverdue.filter { $0.word != "difficult" }
        XCTAssertEqual(
            SmartWordSelection.select(from: withoutDifficult, now: now, calendar: calendar)?.word,
            "learning"
        )
    }

    func testSelectionDeduplicatesIDsAndFallsBackToMasteredWords() {
        let id = UUID()
        let duplicate = make("duplicate", id: id, status: "new")
        let mastered = make("mastered", status: "mastered", successfulReviews: 4)

        XCTAssertEqual(
            SmartWordSelection.select(from: [duplicate, duplicate], now: now, calendar: calendar),
            duplicate
        )
        XCTAssertEqual(
            SmartWordSelection.select(from: [mastered], now: now, calendar: calendar),
            mastered
        )
    }

    func testEmptySnapshotReturnsNoWord() {
        XCTAssertNil(SmartWordSelection.select(from: [], now: now, calendar: calendar))
    }

    func testMasteredFallbackIsStableWithinDayAndCanChangeOnNextDay() {
        let words = (0..<5).map {
            make("mastered-\($0)", status: "mastered", createdAt: now.addingTimeInterval(Double($0)), successfulReviews: 10)
        }

        let first = SmartWordSelection.select(from: words, now: now, calendar: calendar)
        let sameDay = SmartWordSelection.select(from: words, now: now.addingTimeInterval(3_600), calendar: calendar)
        XCTAssertEqual(first?.id, sameDay?.id)
    }

    func testNextDayStartUsesLocalCalendarBoundary() {
        let newYearEve = Date(timeIntervalSince1970: 1_704_067_200) // 2023-12-31 00:00 UTC
        let next = SmartWordTimeline.nextDayStart(after: newYearEve.addingTimeInterval(23 * 3_600), calendar: calendar)
        XCTAssertEqual(next, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: newYearEve)))
    }

    func testTimelineContainsNowAndNextLocalDayBoundary() {
        let dates = SmartWordTimeline.entryDates(from: now, calendar: calendar)

        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(dates[0], now)
        XCTAssertEqual(dates[1], SmartWordTimeline.nextDayStart(after: now, calendar: calendar))
    }

    func testWordDeepLinkCarriesTheSelectedID() {
        let id = UUID()
        let url = LuciusShared.reviewURL(for: id)
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "word" })?
            .value

        XCTAssertEqual(value, id.uuidString)
    }

    func testSameWordRemainsSelectedDuringCurrentDay() {
        let first = make("first", status: "learning", mistakes: 1)
        let second = make("second", status: "new", createdAt: now.addingTimeInterval(1))
        let initial = snapshot(words: [first, second], selected: first)

        let updated = SmartWordSnapshotResolver.updating(
            previous: initial,
            words: [first, second],
            interfaceLanguageCode: "en",
            copy: .english,
            now: now.addingTimeInterval(3_600),
            calendar: calendar
        )

        XCTAssertEqual(updated.selectedWordID, first.id)
        XCTAssertEqual(SmartWordSnapshotResolver.displayedWord(in: updated, at: now, calendar: calendar), first)
    }

    func testRefreshAfterReviewSelectsNextEligibleWord() {
        let first = make("first", status: "learning", mistakes: 1)
        let second = make("second", status: "new", createdAt: now.addingTimeInterval(1))
        let initial = snapshot(words: [first, second], selected: first)

        let afterReview = SharedVocabularyWord(
            id: first.id,
            word: first.word,
            translation: first.translation,
            languageCode: first.languageCode,
            reviewStatus: "mastered",
            difficulty: "medium",
            nextReviewDate: now.addingTimeInterval(86_400),
            createdAt: first.createdAt,
            updatedAt: now,
            mistakeCount: first.mistakeCount,
            successfulReviewCount: first.successfulReviewCount + 1,
            category: first.category
        )
        let updated = SmartWordSnapshotResolver.updating(
            previous: initial,
            words: [afterReview, second],
            interfaceLanguageCode: "en",
            copy: .english,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(updated.selectedWordID, second.id)
    }

    func testRefreshAfterAddingWordUsesNewWordWhenSnapshotWasEmpty() {
        let added = make("added", status: "new")
        let updated = SmartWordSnapshotResolver.updating(
            previous: .empty,
            words: [added],
            interfaceLanguageCode: "en",
            copy: .english,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(updated.selectedWordID, added.id)
        XCTAssertEqual(SmartWordSnapshotResolver.displayedWord(in: updated, at: now, calendar: calendar), added)
    }

    func testRefreshAfterDeletingDisplayedWordSelectsRemainingWord() {
        let deleted = make("deleted", status: "learning", mistakes: 1)
        let remaining = make("remaining", status: "new")
        let initial = snapshot(words: [deleted, remaining], selected: deleted)
        let updated = SmartWordSnapshotResolver.updating(
            previous: initial,
            words: [remaining],
            interfaceLanguageCode: "en",
            copy: .english,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(updated.selectedWordID, remaining.id)
        XCTAssertFalse(updated.words.contains { $0.id == deleted.id })
    }

    func testDeletingOnlyWordProducesEmptyState() {
        let deleted = make("deleted", status: "learning")
        let initial = snapshot(words: [deleted], selected: deleted)
        let updated = SmartWordSnapshotResolver.updating(
            previous: initial,
            words: [],
            interfaceLanguageCode: "en",
            copy: .english,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(updated.selectedWordID)
        XCTAssertNil(SmartWordSnapshotResolver.displayedWord(in: updated, at: now, calendar: calendar))
    }

    private func snapshot(
        words: [SharedVocabularyWord],
        selected: SharedVocabularyWord
    ) -> SmartWordSnapshot {
        SmartWordSnapshot(
            words: words,
            updatedAt: now,
            interfaceLanguageCode: "en",
            selectedWordID: selected.id,
            selectionDay: calendar.startOfDay(for: now)
        )
    }

    private func make(
        _ word: String,
        id: UUID = UUID(),
        status: String,
        difficulty: String = "medium",
        nextReviewDate: Date? = nil,
        createdAt: Date? = nil,
        mistakes: Int = 0,
        successfulReviews: Int = 0
    ) -> SharedVocabularyWord {
        SharedVocabularyWord(
            id: id,
            word: word,
            translation: "translation",
            languageCode: "en",
            reviewStatus: status,
            difficulty: difficulty,
            nextReviewDate: nextReviewDate,
            createdAt: createdAt ?? now,
            updatedAt: createdAt ?? now,
            mistakeCount: mistakes,
            successfulReviewCount: successfulReviews,
            category: nil
        )
    }
}
