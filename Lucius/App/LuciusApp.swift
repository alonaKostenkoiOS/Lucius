import SwiftUI
import SwiftData

@main
struct LuciusApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var router = AppRouter()

    private let modelContainer: ModelContainer

    init() {
        // Reminders are on by default until the user turns them off in Settings.
        UserDefaults.standard.register(defaults: [AppSettingsKeys.notificationsEnabled: true])

        modelContainer = ModelContainerFactory.make()

        // Lets image generation finish and save even after leaving the screen.
        SceneImageGenerationManager.shared.configure(with: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            Group {
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
            .environment(router)
            .onOpenURL { url in
                hasSeenWelcome = true // a deep link implies onboarding is done
                router.handle(url)
            }
        }
        .modelContainer(modelContainer)
    }
}
