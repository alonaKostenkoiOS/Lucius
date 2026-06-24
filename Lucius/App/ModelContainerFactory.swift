import SwiftData

/// Single source of truth for the SwiftData container, so the app and the
/// App Intents (Siri / Shortcuts) open the very same store.
enum ModelContainerFactory {
    static func make() -> ModelContainer {
        do {
            return try ModelContainer(for: VocabularyWord.self, ReviewEvent.self)
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }
    }
}
