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

    init(
        date: Date = .now,
        wasCorrect: Bool,
        wordID: UUID? = nil,
        languageCode: String? = nil,
        answerRawValue: String? = nil
    ) {
        self.date = date
        self.wasCorrect = wasCorrect
        self.wordID = wordID
        self.languageCode = languageCode
        self.answerRawValue = answerRawValue
    }
}
