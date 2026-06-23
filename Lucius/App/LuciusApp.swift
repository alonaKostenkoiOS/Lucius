import SwiftUI
import SwiftData

@main
struct LuciusApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    private let modelContainer: ModelContainer

    init() {
        // Reminders are on by default until the user turns them off in Settings.
        UserDefaults.standard.register(defaults: [AppSettingsKeys.notificationsEnabled: true])

        do {
            modelContainer = try ModelContainer(for: VocabularyWord.self, ReviewEvent.self)
        } catch {
            fatalError("Failed to create the model container: \(error)")
        }

        // Lets image generation finish and save even after leaving the screen.
        SceneImageGenerationManager.shared.configure(with: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            if hasSeenWelcome {
                MainTabView()
            } else {
                WelcomeView {
                    withAnimation(.easeOut) {
                        hasSeenWelcome = true
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
