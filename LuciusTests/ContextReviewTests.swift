import Foundation
import Testing
@testable import Lucius

struct ContextReviewTests {
    @Test func clozeAndRecallIgnoreCapitalization() {
        #expect(
            ContextReviewText.cloze(
                sentence: "I decided to Abandon my old job.",
                word: "abandon"
            ) == "I decided to ____ my old job."
        )
        #expect(ContextReviewText.answersMatch("  ABANDON\n", "abandon"))
        #expect(!ContextReviewText.answersMatch("abandoned", "abandon"))
    }

    @Test func recognitionHasOneCorrectAnswerAndThreeLocalDistractors() {
        let target = VocabularyWord(
            word: "abandon",
            translation: "leave",
            example: "I decided to abandon my old job."
        )
        let vocabulary = [
            target,
            VocabularyWord(word: "collect", translation: "gather"),
            VocabularyWord(word: "improve", translation: "make better"),
            VocabularyWord(word: "discover", translation: "find"),
            VocabularyWord(word: "tiny", translation: "small")
        ]

        let options = ContextReviewEngine.recognitionOptions(
            for: target,
            vocabulary: vocabulary,
            randomize: false
        )

        #expect(options.count == 4)
        #expect(options.first == "abandon")
        #expect(options.count(where: { ContextReviewText.answersMatch($0, "abandon") }) == 1)
    }

    @Test func smallVocabularyFallsBackToRecallWithoutInventingAnswers() {
        let word = VocabularyWord(
            word: "abandon",
            translation: "leave",
            example: "I decided to abandon my old job."
        )

        let question = ContextReviewEngine.makeQuestion(
            for: word,
            vocabulary: [word],
            randomizeOptions: false
        )

        #expect(question.mode == .recall)
        #expect(question.options.isEmpty)
    }

    @Test func missingContextUsesSentenceCreationExercise() {
        let word = VocabularyWord(word: "abandon", translation: "leave")
        let question = ContextReviewEngine.makeQuestion(for: word, vocabulary: [word])

        #expect(question.mode == .use)
        #expect(question.clozeSentence == nil)
    }

    @Test func learnerSentenceIsReusedInFutureQuestions() {
        let word = VocabularyWord(
            word: "abandon",
            translation: "leave",
            example: "I decided to abandon my old job.",
            successfulReviewCount: 1
        )
        word.saveUsageSentence("Never abandon a good friend.")

        let question = ContextReviewEngine.makeQuestion(for: word, vocabulary: [word])

        #expect(question.originalSentence == "Never abandon a good friend.")
        #expect(question.clozeSentence == "Never ____ a good friend.")
    }

    @Test func contextMetricsAreCalculatedOnlyFromLocalEvents() {
        let word = VocabularyWord(
            word: "abandon",
            translation: "leave",
            mistakeCount: 2,
            usageCount: 3
        )
        let events = [
            ReviewEvent(
                wasCorrect: true,
                contextReviewModeRawValue: ContextReviewMode.recognize.rawValue,
                responseTime: 2
            ),
            ReviewEvent(
                wasCorrect: false,
                contextReviewModeRawValue: ContextReviewMode.recognize.rawValue,
                responseTime: 4
            ),
            ReviewEvent(
                wasCorrect: true,
                contextReviewModeRawValue: ContextReviewMode.recall.rawValue,
                responseTime: 6
            )
        ]

        let metrics = ContextReviewMetrics.calculate(words: [word], events: events)

        #expect(metrics.recognitionAccuracy == 0.5)
        #expect(metrics.recallAccuracy == 1)
        #expect(metrics.usageCount == 3)
        #expect(metrics.mistakeCount == 2)
        #expect(metrics.averageResponseTime == 4)
    }
}
