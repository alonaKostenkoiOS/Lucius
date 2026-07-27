import Foundation
import SwiftData

/// The minimum persisted state required to resume one local-calendar-day focus session.
@Model
final class DailyFocusSession {
    @Attribute(.unique) var id: UUID
    var sessionDay: Date
    var wordIDsData: Data
    var completedIDsData: Data
    var currentIndex: Int
    var correctCount: Int
    var incorrectCount: Int
    var isCompleted: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sessionDay: Date,
        wordIDs: [UUID],
        completedIDs: [UUID] = [],
        currentIndex: Int = 0,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        isCompleted: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sessionDay = sessionDay
        self.wordIDsData = (try? JSONEncoder().encode(wordIDs)) ?? Data()
        self.completedIDsData = (try? JSONEncoder().encode(completedIDs)) ?? Data()
        self.currentIndex = currentIndex
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.isCompleted = isCompleted
        self.updatedAt = updatedAt
    }

    var wordIDs: [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: wordIDsData)) ?? []
    }

    var completedIDs: Set<UUID> {
        Set((try? JSONDecoder().decode([UUID].self, from: completedIDsData)) ?? [])
    }

    func replaceWordIDs(_ ids: [UUID], now: Date) {
        wordIDsData = (try? JSONEncoder().encode(ids)) ?? Data()
        currentIndex = min(currentIndex, ids.count)
        isCompleted = !ids.isEmpty && completedIDs.isSuperset(of: Set(ids))
        updatedAt = now
    }

    func record(wordID: UUID, isCorrect: Bool, now: Date) {
        var completed = completedIDs
        completed.insert(wordID)
        completedIDsData = (try? JSONEncoder().encode(Array(completed))) ?? Data()
        if isCorrect { correctCount += 1 } else { incorrectCount += 1 }
        currentIndex = min(completed.count, wordIDs.count)
        isCompleted = !wordIDs.isEmpty && completed.isSuperset(of: Set(wordIDs))
        updatedAt = now
    }
}
