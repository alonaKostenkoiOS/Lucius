import Foundation
import SwiftData

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep
    var learningLanguageCode: String
    var nativeLanguageCode: String
    var goals: Set<OnboardingGoal>
    var contentSources: Set<OnboardingContentSource>
    var level: OnboardingLevel?
    var reviewModes: Set<ReviewPracticeMode>
    var demoWasSaved: Bool
    var reviewAnswer: String?
    private(set) var reviewOptions: [String] = []
    var reviewSubmitted = false
    var isSavingDemo = false

    init() {
        let learning = AppLanguageSettings.learningLanguageCode
        var native = AppLanguageSettings.translationLanguageCode
        if native == learning {
            native = AppLanguageSettings.availableLanguages.first(where: { $0.code != learning })?.code ?? "uk"
        }
        step = OnboardingStore.step
        learningLanguageCode = learning
        nativeLanguageCode = native
        goals = OnboardingStore.goals
        contentSources = OnboardingStore.contentSources
        level = OnboardingStore.level
        demoWasSaved = OnboardingStore.demoSaved && OnboardingStore.demoLanguageCode == learning
        reviewModes = ReviewModePreferences.load(
            audioAvailable: SpeechService.shared.isAvailable(languageCode: learning)
        )
        if reviewModes.isEmpty { reviewModes = [.mixed] }
    }

    var availableLanguages: [LanguageOption] {
        AppLanguageSettings.availableLanguages
    }

    var demo: OnboardingDemoContent {
        OnboardingDemoContent.make(
            learningLanguageCode: learningLanguageCode,
            nativeLanguageCode: nativeLanguageCode
        )
    }

    var canContinueLanguages: Bool {
        !learningLanguageCode.isEmpty
            && !nativeLanguageCode.isEmpty
            && learningLanguageCode != nativeLanguageCode
    }

    var audioAvailable: Bool {
        SpeechService.shared.isAvailable(languageCode: learningLanguageCode)
    }

    var reviewWasCorrect: Bool {
        guard let reviewAnswer else { return false }
        return ContextReviewText.answersMatch(reviewAnswer, demo.word)
    }

    func setLearningLanguage(_ code: String) {
        learningLanguageCode = code
        if nativeLanguageCode == code {
            nativeLanguageCode = availableLanguages.first(where: { $0.code != code })?.code ?? ""
        }
        persistLanguages()
        reviewModes = ReviewModePreferences.load(audioAvailable: audioAvailable)
        demoWasSaved = OnboardingStore.demoSaved && OnboardingStore.demoLanguageCode == code
        reviewOptions = []
        resetReview()
    }

    func setNativeLanguage(_ code: String) {
        guard code != learningLanguageCode else { return }
        nativeLanguageCode = code
        persistLanguages()
    }

    func swapLanguages() {
        guard canContinueLanguages else { return }
        let previousLearning = learningLanguageCode
        learningLanguageCode = nativeLanguageCode
        nativeLanguageCode = previousLearning
        persistLanguages()
        reviewModes = ReviewModePreferences.load(audioAvailable: audioAvailable)
        demoWasSaved = OnboardingStore.demoSaved && OnboardingStore.demoLanguageCode == learningLanguageCode
        reviewOptions = []
        resetReview()
    }

    func persistLanguages() {
        AppLanguageSettings.learningLanguageCode = learningLanguageCode
        AppLanguageSettings.translationLanguageCode = nativeLanguageCode
    }

    func toggleGoal(_ goal: OnboardingGoal) {
        goals.toggleMembership(of: goal)
        OnboardingStore.save(goals: goals)
    }

    func toggleContent(_ source: OnboardingContentSource) {
        contentSources.toggleMembership(of: source)
        OnboardingStore.save(contentSources: contentSources)
    }

    func selectLevel(_ value: OnboardingLevel) {
        level = value
        OnboardingStore.save(level: value)
    }

    func toggleReviewMode(_ mode: ReviewPracticeMode) {
        if mode == .mixed {
            reviewModes = reviewModes == [.mixed] ? [] : [.mixed]
        } else {
            reviewModes.remove(.mixed)
            reviewModes.toggleMembership(of: mode)
        }
        if reviewModes.isEmpty { reviewModes = [.mixed] }
        ReviewModePreferences.save(reviewModes)
    }

    func go(to nextStep: OnboardingStep) {
        step = nextStep
        OnboardingStore.save(step: nextStep)
    }

    func goBack() {
        guard let previous = step.previous else { return }
        step = previous
        OnboardingStore.save(step: previous)
    }

    @discardableResult
    func saveDemoWord(context: ModelContext) -> Bool {
        guard !isSavingDemo else { return false }
        isSavingDemo = true
        defer { isSavingDemo = false }

        let content = demo
        let words = (try? context.fetch(FetchDescriptor<VocabularyWord>())) ?? []
        if words.contains(where: {
            $0.languageCode == content.learningLanguageCode
                && $0.word.localizedCaseInsensitiveCompare(content.word) == .orderedSame
        }) {
            demoWasSaved = true
            OnboardingStore.markDemoSaved(languageCode: content.learningLanguageCode)
            return true
        }

        let newWord = VocabularyWord(
            word: content.word,
            translation: content.translation ?? "",
            languageCode: content.learningLanguageCode,
            example: content.sentence,
            visualAssociation: content.memoryTip,
            bookTitle: "Lucius onboarding",
            difficulty: .medium,
            reviewStatus: .new,
            nextReviewDate: .now
        )
        context.insert(newWord)
        do {
            try context.save()
        } catch {
            context.delete(newWord)
            return false
        }
        demoWasSaved = true
        OnboardingStore.markDemoSaved(languageCode: content.learningLanguageCode)
        return true
    }

    func submitReview(_ answer: String) {
        guard !reviewSubmitted else { return }
        reviewAnswer = answer
        reviewSubmitted = true
        Haptics.selection()
    }

    func prepareReviewOptions() {
        guard reviewOptions.isEmpty else { return }
        reviewOptions = ([demo.word] + demo.distractors).shuffled()
    }

    func resetReview() {
        reviewAnswer = nil
        reviewSubmitted = false
    }

    func complete() {
        OnboardingStore.complete()
        step = .completion
    }
}

private extension Set {
    mutating func toggleMembership(of element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
