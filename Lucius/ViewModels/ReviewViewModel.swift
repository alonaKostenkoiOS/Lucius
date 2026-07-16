import Foundation
import SwiftData

/// Owns a review session while delegating exercise choice to `ReviewModeEngine`.
@Observable
@MainActor
final class ReviewViewModel {
    private(set) var queue: [VocabularyWord] = []
    private(set) var currentQuestion: ContextReviewQuestion?
    private(set) var currentPracticeMode: ReviewPracticeMode?
    private(set) var answerOptions: [String] = []
    private(set) var feedback: ContextReviewFeedback?
    private(set) var sessionTotal = 0
    var celebrate = false

    private var vocabulary: [VocabularyWord] = []
    private var selectedModes: Set<ReviewPracticeMode> = [.mixed]
    private var audioAvailable = false
    private var questionStartedAt = Date.now

    var currentWord: VocabularyWord? { queue.first }
    var remainingCount: Int { queue.count }
    var hasSubmittedAnswer: Bool { feedback != nil }

    var sessionProgress: Double {
        guard sessionTotal > 0 else { return 0 }
        let completed = sessionTotal - queue.count + (hasSubmittedAnswer ? 1 : 0)
        return min(Double(completed) / Double(sessionTotal), 1)
    }

    func loadDueWords(
        context: ModelContext,
        selectedModes: Set<ReviewPracticeMode>,
        audioAvailable: Bool
    ) {
        let now = Date.now
        let languageCode = AppLanguageSettings.learningLanguageCode
        let descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { word in word.languageCode == languageCode }
        )
        vocabulary = (try? context.fetch(descriptor)) ?? []
        queue = vocabulary
            .filter { ($0.nextReviewDate ?? .distantFuture) <= now }
            .sorted { ($0.nextReviewDate ?? .distantFuture) < ($1.nextReviewDate ?? .distantFuture) }
        self.selectedModes = selectedModes
        self.audioAvailable = audioAvailable
        sessionTotal = queue.count
        prepareCurrentQuestion()
    }

    func submitChoice(_ option: String, context: ModelContext) {
        guard let question, let mode = currentPracticeMode,
              mode == .multipleChoice || mode == .listening else { return }
        let expected = mode == .multipleChoice
            ? (question.translation ?? question.correctAnswer)
            : question.correctAnswer
        finish(
            response: option,
            expectedAnswer: expected,
            isCorrect: ContextReviewText.answersMatch(option, expected),
            context: context
        )
    }

    func submitTypedAnswer(_ answer: String, context: ModelContext) {
        guard let question, let mode = currentPracticeMode,
              mode == .cloze || mode == .typeWord else { return }
        finish(
            response: answer,
            expectedAnswer: question.correctAnswer,
            isCorrect: ContextReviewText.answersMatch(answer, question.correctAnswer),
            context: context
        )
    }

    func submitUsage(_ sentence: String, context: ModelContext) {
        guard let question, currentPracticeMode == .useSentence else { return }
        let cleaned = ContextReviewText.cleaned(sentence) ?? ""
        let isCorrect = ContextReviewText.containsTarget(cleaned, word: question.correctAnswer)
        if isCorrect {
            question.word.saveUsageSentence(cleaned)
            question.word.usageCount += 1
        }
        finish(
            response: cleaned,
            expectedAnswer: question.correctAnswer,
            isCorrect: isCorrect,
            context: context
        )
    }

    /// Standard flashcards retain the existing three-confidence scheduler.
    func answerFlashcard(_ answer: ReviewAnswer, context: ModelContext) {
        guard feedback == nil, currentPracticeMode == .flashcards, let word = currentWord else { return }
        let responseTime = max(Date.now.timeIntervalSince(questionStartedAt), 0)
        let outcome = ReviewScheduler.apply(answer, to: word)
        context.insert(ReviewEvent(
            wasCorrect: answer == .knowIt,
            wordID: word.id,
            languageCode: word.languageCode,
            answerRawValue: answer.rawValue,
            responseTime: responseTime,
            reviewPracticeModeRawValue: ReviewPracticeMode.flashcards.rawValue
        ))
        persist(outcome: outcome, word: word, isCorrect: answer != .forgot, context: context)
        queue.removeFirst()
        prepareCurrentQuestion()
    }

    func continueReview() {
        guard feedback != nil, !queue.isEmpty else { return }
        queue.removeFirst()
        prepareCurrentQuestion()
    }

    private var question: ContextReviewQuestion? { currentQuestion }

    private func prepareCurrentQuestion() {
        feedback = nil
        answerOptions = []
        guard let word = queue.first else {
            currentQuestion = nil
            currentPracticeMode = nil
            return
        }

        let mode = ReviewModeEngine.chooseMode(
            for: word,
            vocabulary: vocabulary,
            selection: selectedModes,
            audioAvailable: audioAvailable
        )
        currentPracticeMode = mode

        let original = ReviewModeEngine.context(for: word)
        let contextMode: ContextReviewMode = switch mode {
        case .cloze, .typeWord: .recall
        case .useSentence: .use
        case .multipleChoice, .listening, .flashcards, .mixed: .recognize
        }
        currentQuestion = ContextReviewQuestion(
            word: word,
            mode: contextMode,
            originalSentence: original,
            clozeSentence: ContextReviewText.cloze(sentence: original, word: word.word),
            options: []
        )

        switch mode {
        case .multipleChoice:
            answerOptions = ReviewModeEngine.translationOptions(for: word, vocabulary: vocabulary)
        case .listening:
            answerOptions = ContextReviewEngine.recognitionOptions(for: word, vocabulary: vocabulary)
        default:
            break
        }
        questionStartedAt = .now
    }

    private func finish(
        response: String,
        expectedAnswer: String,
        isCorrect: Bool,
        context: ModelContext
    ) {
        guard feedback == nil, let question, let practiceMode = currentPracticeMode else { return }
        let responseTime = max(Date.now.timeIntervalSince(questionStartedAt), 0)
        let schedulerAnswer: ReviewAnswer = isCorrect ? .knowIt : .forgot
        let outcome = ReviewScheduler.apply(schedulerAnswer, to: question.word)

        context.insert(ReviewEvent(
            wasCorrect: isCorrect,
            wordID: question.word.id,
            languageCode: question.word.languageCode,
            answerRawValue: schedulerAnswer.rawValue,
            contextReviewModeRawValue: question.mode.rawValue,
            responseTime: responseTime,
            responseText: String(response.prefix(500)),
            reviewPracticeModeRawValue: practiceMode.rawValue
        ))

        feedback = ContextReviewFeedback(
            isCorrect: isCorrect,
            submittedAnswer: response,
            correctAnswer: expectedAnswer,
            originalSentence: question.originalSentence,
            translation: question.translation,
            explanation: practiceMode == .useSentence && !isCorrect
                ? "Your sentence needs to include “\(question.correctAnswer)”."
                : question.explanation,
            memoryTip: question.memoryTip,
            responseTime: responseTime
        )

        persist(outcome: outcome, word: question.word, isCorrect: isCorrect, context: context)
    }

    private func persist(
        outcome: ReviewOutcome,
        word: VocabularyWord,
        isCorrect: Bool,
        context: ModelContext
    ) {
        try? context.save()
        NotificationService.shared.scheduleReviewNotification(for: word)
        WidgetSync.update(context: context)

        if outcome.didReachMastered {
            celebrate = true
            Haptics.success()
        } else if isCorrect {
            Haptics.success()
        } else {
            Haptics.error()
        }
    }
}
