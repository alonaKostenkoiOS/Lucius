import OSLog
import SwiftData

/// Single source of truth for the SwiftData container, so the app and the
/// App Intents (Siri / Shortcuts) open the very same store.
enum ModelContainerFactory {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.lucius.app",
        category: "Persistence"
    )

    static func make() -> ModelContainer {
        do {
            return try ModelContainer(for: VocabularyWord.self, ReviewEvent.self, DailyFocusSession.self)
        } catch {
            logger.fault("Persistent model container failed: \(error.localizedDescription, privacy: .public)")

            // Keep the app usable instead of crashing at launch. The fallback
            // deliberately does not delete or overwrite the persistent store,
            // so a later app update can still migrate or recover user data.
            do {
                let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: VocabularyWord.self,
                    ReviewEvent.self,
                    DailyFocusSession.self,
                    configurations: fallback
                )
            } catch {
                preconditionFailure("Unable to create even an in-memory model container: \(error)")
            }
        }
    }
}
