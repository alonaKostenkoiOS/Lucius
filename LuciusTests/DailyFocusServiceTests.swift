import Foundation
import SwiftData
import Testing
@testable import Lucius

@MainActor
struct DailyFocusServiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func prioritizesOverdueThenDifficultLearningAndRecent() {
        let words = [
            VocabularyWord(word: "overdue", translation: "1", reviewStatus: .familiar, nextReviewDate: now.addingTimeInterval(-3_600), createdAt: now.addingTimeInterval(-5)),
            VocabularyWord(word: "difficult", translation: "2", reviewStatus: .familiar, nextReviewDate: now.addingTimeInterval(86_400), createdAt: now.addingTimeInterval(-4), mistakeCount: 4),
            VocabularyWord(word: "learning", translation: "3", reviewStatus: .learning, nextReviewDate: now.addingTimeInterval(43_200), createdAt: now.addingTimeInterval(-3)),
            VocabularyWord(word: "recent", translation: "4", reviewStatus: .new, createdAt: now.addingTimeInterval(-1)),
            VocabularyWord(word: "another", translation: "5", reviewStatus: .new, createdAt: now.addingTimeInterval(-2)),
            VocabularyWord(word: "not-due", translation: "6", reviewStatus: .familiar, nextReviewDate: now.addingTimeInterval(86_400))
        ]

        let selected = DailyFocusService.selectWords(from: words, now: now, calendar: calendar)

        #expect(selected.count == 5)
        #expect(selected.prefix(3).map { $0.word } == ["overdue", "difficult", "learning"])
        #expect(selected.contains { $0.word == "recent" })
        #expect(!selected.contains { $0.word == "not-due" })
    }

    @Test func selectionIsCappedAndDeduplicated() {
        let id = UUID()
        let duplicate = VocabularyWord(id: id, word: "same", translation: "same")
        let words = [duplicate, duplicate] + (0..<8).map {
            VocabularyWord(word: "word\($0)", translation: "translation\($0)")
        }

        let selected = DailyFocusService.selectWords(from: words, now: now, calendar: calendar)

        #expect(selected.count == DailyFocusService.maximumItems)
        #expect(Set(selected.map(\.id)).count == selected.count)
    }

    @Test func sessionIsStableForTheSameDayAndResetsOnTheNextDay() throws {
        let context = try makeContext()
        context.insert(VocabularyWord(word: "stable", translation: "стабільний", createdAt: now))

        let first = DailyFocusService.loadOrCreate(context: context, now: now, calendar: calendar, languageCode: "en")
        let second = DailyFocusService.loadOrCreate(context: context, now: now.addingTimeInterval(3_600), calendar: calendar, languageCode: "en")
        let nextDay = DailyFocusService.loadOrCreate(context: context, now: now.addingTimeInterval(86_400), calendar: calendar, languageCode: "en")

        #expect(first.session?.id == second.session?.id)
        #expect(first.session?.wordIDs == second.session?.wordIDs)
        #expect(nextDay.session?.id != first.session?.id)
    }

    @Test func restoresProgressAndSkipsMissingWords() throws {
        let context = try makeContext()
        let word = VocabularyWord(word: "kept", translation: "залишений", createdAt: now)
        let missingID = UUID()
        context.insert(word)
        let session = DailyFocusSession(
            sessionDay: calendar.startOfDay(for: now),
            wordIDs: [word.id, missingID],
            updatedAt: now
        )
        context.insert(session)
        try context.save()

        DailyFocusService.record(wordID: word.id, isCorrect: true, session: session, context: context, now: now)
        let restored = DailyFocusService.loadOrCreate(context: context, now: now, calendar: calendar, languageCode: "en")

        #expect(restored.session?.id == session.id)
        #expect(restored.session?.wordIDs == [word.id])
        #expect(restored.session?.completedIDs == Set([word.id]))
        #expect(restored.session?.correctCount == 1)
        #expect(restored.session?.incorrectCount == 0)
        #expect(restored.session?.isCompleted == true)
    }

    @Test func returnsEmptyWhenNoEligibleWordsExist() throws {
        let context = try makeContext()
        context.insert(VocabularyWord(
            word: "mastered",
            translation: "вивчене",
            languageCode: "en",
            reviewStatus: .mastered,
            nextReviewDate: now.addingTimeInterval(86_400),
            createdAt: now
        ))

        let result = DailyFocusService.loadOrCreate(context: context, now: now, calendar: calendar, languageCode: "en")

        #expect(result.session == nil)
        #expect(result.words.isEmpty)
    }

    @Test func reviewModeFallsBackToFlashcardWhenContextIsUnavailable() {
        let word = VocabularyWord(word: "word", translation: "переклад")

        let mode = ReviewModeEngine.chooseMode(
            for: word,
            vocabulary: [word],
            selection: [.cloze],
            audioAvailable: false
        )

        #expect(mode == .flashcards)
    }

    @Test func progressReflectsCompletedItemsOnly() throws {
        let context = try makeContext()
        let first = VocabularyWord(word: "first", translation: "перший", createdAt: now)
        let second = VocabularyWord(word: "second", translation: "другий", createdAt: now)
        context.insert(first)
        context.insert(second)
        let session = DailyFocusSession(
            sessionDay: calendar.startOfDay(for: now),
            wordIDs: [first.id, second.id],
            updatedAt: now
        )
        context.insert(session)
        try context.save()
        DailyFocusService.record(wordID: first.id, isCorrect: false, session: session, context: context, now: now)

        let viewModel = DailyFocusViewModel()
        viewModel.refresh(context: context, now: now, calendar: calendar)

        #expect(viewModel.completedCount == 1)
        #expect(viewModel.progress == 0.5)
        #expect(viewModel.isInProgress)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: VocabularyWord.self,
            ReviewEvent.self,
            DailyFocusSession.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
