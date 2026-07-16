import Foundation
import SwiftData

/// A lightweight log of every answered review, used to draw the
/// activity heatmap and streak on the home screen. One row per answer.
@Model
final class ReviewEvent {
    var date: Date
    /// Whether the answer was "I know it" — lets the heatmap weight
    /// confident recalls differently from struggles if we want to later.
    var wasCorrect: Bool
    /// Optional linkage added for per-word analytics. Old events remain valid.
    var wordID: UUID?
    var languageCode: String?
    var answerRawValue: String?
    /// Optional context-review metadata. Nil values keep legacy events readable.
    var contextReviewModeRawValue: String?
    var responseTime: TimeInterval?
    var responseText: String?
    var reviewPracticeModeRawValue: String?

    init(
        date: Date = .now,
        wasCorrect: Bool,
        wordID: UUID? = nil,
        languageCode: String? = nil,
        answerRawValue: String? = nil,
        contextReviewModeRawValue: String? = nil,
        responseTime: TimeInterval? = nil,
        responseText: String? = nil,
        reviewPracticeModeRawValue: String? = nil
    ) {
        self.date = date
        self.wasCorrect = wasCorrect
        self.wordID = wordID
        self.languageCode = languageCode
        self.answerRawValue = answerRawValue
        self.contextReviewModeRawValue = contextReviewModeRawValue
        self.responseTime = responseTime
        self.responseText = responseText
        self.reviewPracticeModeRawValue = reviewPracticeModeRawValue
    }
}
