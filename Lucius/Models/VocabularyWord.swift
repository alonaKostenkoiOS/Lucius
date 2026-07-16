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
    /// Context-review data is additive so existing stores migrate without losing cards.
    var usageCount: Int = 0
    var savedUsageSentencesData: Data?
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
        firstMasteredAt: Date? = nil,
        usageCount: Int = 0,
        savedUsageSentencesData: Data? = nil
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
        self.usageCount = usageCount
        self.savedUsageSentencesData = savedUsageSentencesData
    }

    /// A word is due when its scheduled review moment has passed.
    var isDueForReview: Bool {
        guard let nextReviewDate else { return false }
        return nextReviewDate <= .now
    }

    /// Sentences created during the Use exercise, kept as JSON in the existing word row.
    var savedUsageSentences: [String] {
        guard let savedUsageSentencesData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: savedUsageSentencesData)) ?? []
    }

    func saveUsageSentence(_ sentence: String) {
        var sentences = savedUsageSentences
        guard !sentences.contains(where: {
            $0.localizedCaseInsensitiveCompare(sentence) == .orderedSame
        }) else { return }
        sentences.append(sentence)
        savedUsageSentencesData = try? JSONEncoder().encode(sentences)
    }
}
