import Foundation
import SwiftData

/// A single vocabulary card: the word itself plus the memory "scene" around it.
@Model
final class VocabularyWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var translation: String
    var example: String?
    var visualAssociation: String?
    var bookTitle: String?
    var chapter: String?
    var difficulty: WordDifficulty
    var reviewStatus: ReviewStatus
    var nextReviewDate: Date?
    var createdAt: Date
    var updatedAt: Date
    /// AI-generated scene image (Image Playground), stored outside the database.
    @Attribute(.externalStorage) var sceneImageData: Data?

    init(
        id: UUID = UUID(),
        word: String,
        translation: String,
        example: String? = nil,
        visualAssociation: String? = nil,
        bookTitle: String? = nil,
        chapter: String? = nil,
        difficulty: WordDifficulty = .medium,
        reviewStatus: ReviewStatus = .new,
        nextReviewDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.word = word
        self.translation = translation
        self.example = example
        self.visualAssociation = visualAssociation
        self.bookTitle = bookTitle
        self.chapter = chapter
        self.difficulty = difficulty
        self.reviewStatus = reviewStatus
        self.nextReviewDate = nextReviewDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A word is due when its scheduled review moment has passed.
    var isDueForReview: Bool {
        guard let nextReviewDate else { return false }
        return nextReviewDate <= .now
    }
}
