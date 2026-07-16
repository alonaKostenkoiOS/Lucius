import Foundation
import SwiftData

/// The review session: a queue of due words answered one by one.
@Observable
@MainActor
final class ReviewViewModel {
    private(set) var queue: [VocabularyWord] = []
    private(set) var isAnswerRevealed = false

    /// Set briefly when the latest answer pushed a word to mastered,
    /// so the view can fire a celebration. The view clears it.
    var celebrate = false
    /// Total words that were due when this session started — used for the
    /// session progress bar.
    private(set) var sessionTotal = 0

    var currentWord: VocabularyWord? { queue.first }
    var remainingCount: Int { queue.count }

    var sessionProgress: Double {
        guard sessionTotal > 0 else { return 0 }
        return Double(sessionTotal - queue.count) / Double(sessionTotal)
    }

    func loadDueWords(context: ModelContext) {
        let now = Date.now
        let languageCode = AppLanguageSettings.learningLanguageCode
        let descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { word in
                word.languageCode == languageCode
                    && word.nextReviewDate != nil
                    && (word.nextReviewDate ?? now) <= now
            },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        queue = (try? context.fetch(descriptor)) ?? []
        sessionTotal = queue.count
        isAnswerRevealed = false
    }

    func revealAnswer() {
        isAnswerRevealed = true
    }

    /// Applies the answer to the current word and moves to the next one.
    func answer(_ answer: ReviewAnswer, context: ModelContext) {
        guard let word = currentWord else { return }

        let outcome = ReviewScheduler.apply(answer, to: word)
        context.insert(ReviewEvent(
            wasCorrect: answer == .knowIt,
            wordID: word.id,
            languageCode: word.languageCode,
            answerRawValue: answer.rawValue
        ))
        try? context.save()
        NotificationService.shared.scheduleReviewNotification(for: word)

        if outcome.didReachMastered {
            celebrate = true
            Haptics.success()
        }

        queue.removeFirst()
        isAnswerRevealed = false

        WidgetSync.update(context: context)
    }
}
