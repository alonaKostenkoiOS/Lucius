import Foundation

/// How the user answered during a review.
enum ReviewAnswer {
    case knowIt
    case almost
    case forgot
}

/// What an answer did to a word — lets the UI celebrate a fresh "mastered".
struct ReviewOutcome {
    /// True only when this answer pushed the word into `.mastered`
    /// for the first time (i.e. it wasn't mastered before).
    let didReachMastered: Bool
}

/// Pure spaced-repetition rules: when to review a word next.
/// Stateless on purpose — easy to test and reason about.
enum ReviewScheduler {
    private static let thirtyMinutes: TimeInterval = 30 * 60
    private static let sixHours: TimeInterval = 6 * 60 * 60
    private static let oneDay: TimeInterval = 24 * 60 * 60
    private static let sevenDays: TimeInterval = 7 * 24 * 60 * 60
    private static let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

    /// First review delay after a word is added, based on perceived difficulty.
    static func firstReviewDate(for difficulty: WordDifficulty, from now: Date = .now) -> Date {
        switch difficulty {
        case .easy: now.addingTimeInterval(oneDay)
        case .medium: now.addingTimeInterval(sixHours)
        case .hard: now.addingTimeInterval(thirtyMinutes)
        }
    }

    /// Applies a review answer to the word: advances its status
    /// and schedules the next review date. Returns what changed.
    @discardableResult
    static func apply(_ answer: ReviewAnswer, to word: VocabularyWord, now: Date = .now) -> ReviewOutcome {
        let wasMastered = word.reviewStatus == .mastered

        switch answer {
        case .forgot:
            word.reviewStatus = .learning
            word.nextReviewDate = now.addingTimeInterval(thirtyMinutes)

        case .almost:
            word.reviewStatus = .familiar
            word.nextReviewDate = now.addingTimeInterval(oneDay)

        case .knowIt:
            switch word.reviewStatus {
            case .new, .learning:
                word.reviewStatus = .familiar
            case .familiar, .mastered:
                word.reviewStatus = .mastered
            }
            let interval = word.reviewStatus == .mastered ? thirtyDays : sevenDays
            word.nextReviewDate = now.addingTimeInterval(interval)
        }

        word.updatedAt = now
        return ReviewOutcome(didReachMastered: !wasMastered && word.reviewStatus == .mastered)
    }
}
