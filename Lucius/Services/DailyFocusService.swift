import Foundation
import SwiftData

enum DailyFocusService {
    static let maximumItems = 5

    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func selectWords(
        from words: [VocabularyWord],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = maximumItems
    ) -> [VocabularyWord] {
        let eligible = words.filter { word in
            let isOverdue = word.nextReviewDate.map { $0 <= now } ?? false
            return isOverdue || word.reviewStatus != .mastered
        }

        // Preserve the source order while removing duplicate model rows. A
        // dictionary-based deduplication can reorder equal-priority items,
        // which makes a newly generated session feel random when timestamps
        // are identical.
        var unique: [VocabularyWord] = []
        var seenIDs = Set<UUID>()
        for word in eligible where seenIDs.insert(word.id).inserted {
            unique.append(word)
        }
        let overdue = unique.filter { ($0.nextReviewDate ?? .distantFuture) <= now }
        let difficult = unique.filter { $0.difficulty == .hard || $0.mistakeCount > 0 }
        let learning = unique.filter { $0.reviewStatus == .learning }
        // A scheduled familiar word is not "recently added" merely because it
        // has no successful reviews yet. Keep this bucket limited to genuinely
        // new cards so words that are not due cannot displace eligible work.
        let recent = unique.filter {
            $0.reviewStatus == .new && $0.successfulReviewCount == 0
        }

        var result: [VocabularyWord] = []
        var seen = Set<UUID>()
        func append(_ candidates: [VocabularyWord], by areInOrder: (VocabularyWord, VocabularyWord) -> Bool) {
            for word in candidates.sorted(by: areInOrder) where result.count < limit {
                guard seen.insert(word.id).inserted else { continue }
                result.append(word)
            }
        }

        append(overdue) {
            let lhsDate = $0.nextReviewDate ?? .distantPast
            let rhsDate = $1.nextReviewDate ?? .distantPast
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        append(difficult) {
            if $0.mistakeCount != $1.mistakeCount {
                return $0.mistakeCount > $1.mistakeCount
            }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        append(learning) {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        append(recent) {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let selectedIDs = Set(result.map(\.id))
        append(unique.filter { !selectedIDs.contains($0.id) }) {
            let lhsDate = $0.nextReviewDate ?? .distantFuture
            let rhsDate = $1.nextReviewDate ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt < $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        return result
    }

    @MainActor
    static func loadOrCreate(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current,
        languageCode: String = AppLanguageSettings.learningLanguageCode
    ) -> (session: DailyFocusSession?, words: [VocabularyWord]) {
        let day = startOfDay(for: now, calendar: calendar)
        let sessions = (try? context.fetch(FetchDescriptor<DailyFocusSession>())) ?? []
        let current = sessions.first { calendar.isDate($0.sessionDay, inSameDayAs: day) }
        let words = (try? context.fetch(FetchDescriptor<VocabularyWord>()))?.filter { $0.languageCode == languageCode } ?? []

        if let current {
            let validIDs = current.wordIDs.filter { id in words.contains { $0.id == id } }
            if validIDs != current.wordIDs { current.replaceWordIDs(validIDs, now: now) }
            let validWords = validIDs.compactMap { id in words.first { $0.id == id } }
            if !validWords.isEmpty {
                try? context.save()
                return (current, validWords)
            }
            context.delete(current)
        }

        let selected = selectWords(from: words, now: now, calendar: calendar)
        guard !selected.isEmpty else { return (nil, []) }
        let session = DailyFocusSession(sessionDay: day, wordIDs: selected.map(\.id), updatedAt: now)
        context.insert(session)
        try? context.save()
        return (session, selected)
    }

    @MainActor
    static func record(
        wordID: UUID,
        isCorrect: Bool,
        session: DailyFocusSession,
        context: ModelContext,
        now: Date = .now
    ) {
        guard session.wordIDs.contains(wordID), !session.completedIDs.contains(wordID) else { return }
        session.record(wordID: wordID, isCorrect: isCorrect, now: now)
        try? context.save()
    }

    static func modeSequence(audioAvailable: Bool) -> [ReviewPracticeMode] {
        let modes: [ReviewPracticeMode] = audioAvailable
            ? [.multipleChoice, .cloze, .flashcards, .multipleChoice, .cloze]
            : [.cloze, .typeWord, .flashcards, .cloze, .typeWord]
        return modes
    }
}
