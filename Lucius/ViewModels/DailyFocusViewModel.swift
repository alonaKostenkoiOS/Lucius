import Foundation
import SwiftData

@MainActor
@Observable
final class DailyFocusViewModel {
    private(set) var session: DailyFocusSession?
    private(set) var wordCount = 0

    var completedCount: Int {
        guard let session else { return 0 }
        return session.completedIDs.intersection(session.wordIDs).count
    }

    var progress: Double {
        guard wordCount > 0 else { return 0 }
        return Double(completedCount) / Double(wordCount)
    }

    var isCompleted: Bool { session?.isCompleted == true }
    var isInProgress: Bool { completedCount > 0 && !isCompleted }

    var estimatedMinutes: Int {
        max(1, Int(ceil(Double(max(wordCount, 1) * 35) / 60)))
    }

    func refresh(context: ModelContext) {
        let result = DailyFocusService.loadOrCreate(context: context)
        session = result.session
        wordCount = result.words.count
    }

    func refresh(context: ModelContext, now: Date, calendar: Calendar) {
        let result = DailyFocusService.loadOrCreate(context: context, now: now, calendar: calendar)
        session = result.session
        wordCount = result.words.count
    }
}
