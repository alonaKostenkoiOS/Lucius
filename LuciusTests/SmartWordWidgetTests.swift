import Foundation
import XCTest
@testable import Lucius

final class SmartWordWidgetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testPriorityOrder() {
        let words = [
            make("mastered", .mastered),
            make("recent", .recent),
            make("learning", .learning),
            make("difficult", .difficult),
            make("overdue", .overdue),
        ]
        XCTAssertEqual(SmartWordSelection.select(from: words, now: now, calendar: calendar)?.word, "overdue")
        XCTAssertEqual(SmartWordSelection.select(from: Array(words.dropLast()), now: now, calendar: calendar)?.word, "difficult")
        XCTAssertEqual(SmartWordSelection.select(from: Array(words.dropLast(2)), now: now, calendar: calendar)?.word, "learning")
    }

    func testEmptyStateHasNoSelectedWord() {
        let payload = SmartWordPayloadResolver.update(
            previous: .empty,
            candidates: [],
            now: now,
            calendar: calendar
        )
        XCTAssertNil(payload.selectedWord)
    }

    func testOneWordIsSelectedAndPreservedForDay() {
        let word = make("café", .recent)
        let first = resolve(.empty, [word])
        let later = SmartWordPayloadResolver.update(
            previous: first,
            candidates: [word],
            now: now.addingTimeInterval(3_600),
            calendar: calendar
        )
        XCTAssertEqual(first.selectedWord, word)
        XCTAssertEqual(later.selectedWord, word)
    }

    func testAddedWordPopulatesAnEmptySnapshot() {
        let added = make("résumé", .recent)
        XCTAssertEqual(resolve(.empty, [added]).selectedWord, added)
    }

    func testDeletingDisplayedWordSelectsRemainingWord() {
        let deleted = make("deleted", .overdue)
        let remaining = make("remaining", .learning)
        let previous = payload(selected: deleted)
        XCTAssertEqual(resolve(previous, [remaining]).selectedWord, remaining)
    }

    func testDeletingOnlyWordReturnsEmptyState() {
        XCTAssertNil(resolve(payload(selected: make("only", .learning)), []).selectedWord)
    }

    func testReviewingDisplayedWordSelectsNextEligibleWord() {
        let reviewed = make("reviewed", .overdue)
        let changed = WidgetWordSnapshot(
            id: reviewed.id,
            word: reviewed.word,
            shortTranslation: reviewed.shortTranslation,
            reviewPriority: .mastered,
            lastUpdated: reviewed.lastUpdated.addingTimeInterval(1)
        )
        let next = make("next", .learning)
        XCTAssertEqual(resolve(payload(selected: reviewed), [changed, next]).selectedWord, next)
    }

    func testLongAndAccentedContentRoundTripsWithoutDatabase() throws {
        let word = make(String(repeating: "é", count: 80), .recent, translation: String(repeating: "übersetzung ", count: 30))
        let original = payload(selected: word)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(SharedStore.decodeSmartWord(data), original)
    }

    func testTranslationSnapshotIsNormalizedAndBounded() {
        let result = WidgetSync.shortTranslation("  très\nlongue   traduction " + String(repeating: "x", count: 200))
        XCTAssertFalse(result.contains("\n"))
        XCTAssertFalse(result.contains("  "))
        XCTAssertLessThanOrEqual(result.count, 160)
    }

    func testMissingAndCorruptedDataFailSafely() {
        XCTAssertEqual(SharedStore.decodeSmartWord(nil), .empty)
        XCTAssertEqual(SharedStore.decodeSmartWord(Data("not-json".utf8)), .empty)
    }

    func testTimelineRefreshesAtNextLocalDayBoundary() {
        let dates = SmartWordTimeline.entryDates(from: now, calendar: calendar)
        XCTAssertEqual(dates, [now, SmartWordTimeline.nextDayStart(after: now, calendar: calendar)])
    }

    func testDeepLinksTargetReviewAndAddFlows() {
        let id = UUID()
        XCTAssertTrue(LuciusShared.reviewURL(for: id).absoluteString.contains(id.uuidString))
        XCTAssertEqual(LuciusShared.addWordURL.host, "add")
    }

    private func resolve(
        _ previous: SmartWordWidgetPayload,
        _ candidates: [WidgetWordSnapshot]
    ) -> SmartWordWidgetPayload {
        SmartWordPayloadResolver.update(
            previous: previous,
            candidates: candidates,
            now: now,
            calendar: calendar
        )
    }

    private func payload(selected: WidgetWordSnapshot) -> SmartWordWidgetPayload {
        SmartWordWidgetPayload(
            version: SmartWordWidgetPayload.currentVersion,
            selectedWord: selected,
            selectionDay: calendar.startOfDay(for: now)
        )
    }

    private func make(
        _ word: String,
        _ priority: WidgetReviewPriority,
        translation: String = "translation"
    ) -> WidgetWordSnapshot {
        WidgetWordSnapshot(
            id: UUID(),
            word: word,
            shortTranslation: translation,
            reviewPriority: priority,
            lastUpdated: now
        )
    }
}
