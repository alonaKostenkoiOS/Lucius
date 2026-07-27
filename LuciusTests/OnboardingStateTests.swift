import Foundation
import Testing
@testable import Lucius

@MainActor
struct OnboardingStateTests {
    @Test func onboardingStepAndSelectionsPersistLocally() {
        let defaults = UserDefaults.standard
        let previousStep = defaults.string(forKey: "luciusOnboardingStep")
        let previousGoals = defaults.stringArray(forKey: "luciusOnboardingGoals")
        let previousContent = defaults.stringArray(forKey: "luciusOnboardingContent")
        let previousLevel = defaults.string(forKey: "luciusOnboardingLevel")

        defer {
            defaults.set(previousStep, forKey: "luciusOnboardingStep")
            defaults.set(previousGoals, forKey: "luciusOnboardingGoals")
            defaults.set(previousContent, forKey: "luciusOnboardingContent")
            defaults.set(previousLevel, forKey: "luciusOnboardingLevel")
        }

        OnboardingStore.save(step: .reviewModes)
        OnboardingStore.save(goals: [.books, .curious])
        OnboardingStore.save(contentSources: [.books, .articles])
        OnboardingStore.save(level: .intermediate)

        #expect(OnboardingStore.step == .reviewModes)
        #expect(OnboardingStore.goals == [.books, .curious])
        #expect(OnboardingStore.contentSources == [.books, .articles])
        #expect(OnboardingStore.level == .intermediate)
    }

    @Test func completionPersistsAndUsesCompletionStep() {
        let defaults = UserDefaults.standard
        let previousCompletion = defaults.object(forKey: OnboardingStore.completionKey)
        let previousStep = defaults.string(forKey: "luciusOnboardingStep")
        let previousWelcome = defaults.object(forKey: "hasSeenWelcome")

        defer {
            if let previousCompletion {
                defaults.set(previousCompletion, forKey: OnboardingStore.completionKey)
            } else {
                defaults.removeObject(forKey: OnboardingStore.completionKey)
            }
            defaults.set(previousStep, forKey: "luciusOnboardingStep")
            if let previousWelcome {
                defaults.set(previousWelcome, forKey: "hasSeenWelcome")
            } else {
                defaults.removeObject(forKey: "hasSeenWelcome")
            }
        }

        OnboardingStore.complete()

        #expect(OnboardingStore.hasCompleted)
        #expect(OnboardingStore.step == .completion)
    }

    @Test func sameLanguageCannotBeAcceptedAsBothLanguages() {
        let previousLearning = AppLanguageSettings.learningLanguageCode
        let previousNative = AppLanguageSettings.translationLanguageCode
        defer {
            AppLanguageSettings.learningLanguageCode = previousLearning
            AppLanguageSettings.translationLanguageCode = previousNative
        }

        let viewModel = OnboardingViewModel()
        viewModel.setLearningLanguage("en")
        viewModel.setNativeLanguage("en")

        #expect(viewModel.learningLanguageCode != viewModel.nativeLanguageCode)
        #expect(viewModel.canContinueLanguages)
    }

    @Test func localizedDemoContentUsesSelectedLanguageWhenAvailable() {
        let content = OnboardingDemoContent.make(learningLanguageCode: "es", nativeLanguageCode: "en")

        #expect(content.word == "abandonar")
        #expect(content.sentence.contains("abandonar"))
        #expect(content.translation == "to abandon")
    }
}
