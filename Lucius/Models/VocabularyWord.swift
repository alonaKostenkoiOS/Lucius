import Foundation
import SwiftData

/// A single vocabulary card: the word itself plus the memory "scene" around it.
@Model
final class VocabularyWord {
    @Attribute(.unique) var id: UUID
    var word: String
    var translation: String
    var languageCode: String = "en"
    var example: String?
    var visualAssociation: String?
    var bookTitle: String?
    var chapter: String?
    var difficulty: WordDifficulty
    var reviewStatus: ReviewStatus
    var nextReviewDate: Date?
    var createdAt: Date
    var updatedAt: Date
    /// Additive analytics counters. Defaults preserve existing SwiftData stores.
    var mistakeCount: Int = 0
    var successfulReviewCount: Int = 0
    var firstMasteredAt: Date?
    /// AI-generated scene image (Image Playground), stored outside the database.
    @Attribute(.externalStorage) var sceneImageData: Data?

    init(
        id: UUID = UUID(),
        word: String,
        translation: String,
        languageCode: String = AppLanguageSettings.learningLanguageCode,
        example: String? = nil,
        visualAssociation: String? = nil,
        bookTitle: String? = nil,
        chapter: String? = nil,
        difficulty: WordDifficulty = .medium,
        reviewStatus: ReviewStatus = .new,
        nextReviewDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mistakeCount: Int = 0,
        successfulReviewCount: Int = 0,
        firstMasteredAt: Date? = nil
    ) {
        self.id = id
        self.word = word
        self.translation = translation
        self.languageCode = languageCode
        self.example = example
        self.visualAssociation = visualAssociation
        self.bookTitle = bookTitle
        self.chapter = chapter
        self.difficulty = difficulty
        self.reviewStatus = reviewStatus
        self.nextReviewDate = nextReviewDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mistakeCount = mistakeCount
        self.successfulReviewCount = successfulReviewCount
        self.firstMasteredAt = firstMasteredAt
    }

    /// A word is due when its scheduled review moment has passed.
    var isDueForReview: Bool {
        guard let nextReviewDate else { return false }
        return nextReviewDate <= .now
    }
}
