import Foundation
import SwiftData

@Observable
@MainActor
final class VocabularyInsightsViewModel {
    private(set) var snapshot = VocabularyAnalyticsSnapshot.empty

    func refresh(context: ModelContext, languageCode: String) {
        let words = (try? context.fetch(FetchDescriptor<VocabularyWord>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<ReviewEvent>())) ?? []
        snapshot = VocabularyAnalyticsEngine.makeSnapshot(
            words: words,
            reviewEvents: events,
            languageCode: languageCode,
            cefrLookup: LocalCEFRDictionary.load()
        )
    }
}
