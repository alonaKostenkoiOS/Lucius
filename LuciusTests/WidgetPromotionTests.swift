import Foundation
import Testing
@testable import Lucius

@Suite("Widget promotion", .serialized)
struct WidgetPromotionTests {
    private let suiteName = "WidgetPromotionTests"

    @Test func appearsOnlyAfterSeveralWordsAndCompletedOnboarding() {
        let defaults = makeDefaults()

        #expect(!WidgetPromotionStore.shouldSuggest(
            wordCount: 0,
            onboardingCompleted: true,
            defaults: defaults
        ))
        #expect(!WidgetPromotionStore.shouldSuggest(
            wordCount: WidgetPromotionStore.minimumWordCount,
            onboardingCompleted: false,
            defaults: defaults
        ))
        #expect(WidgetPromotionStore.shouldSuggest(
            wordCount: WidgetPromotionStore.minimumWordCount,
            onboardingCompleted: true,
            defaults: defaults
        ))
    }

    @Test func dismissalPersistsAndPreventsFutureSuggestions() {
        let defaults = makeDefaults()
        WidgetPromotionStore.dismiss(defaults: defaults)

        #expect(defaults.bool(forKey: WidgetPromotionStore.dismissedKey))
        #expect(!WidgetPromotionStore.shouldSuggest(
            wordCount: 100,
            onboardingCompleted: true,
            defaults: defaults
        ))
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

