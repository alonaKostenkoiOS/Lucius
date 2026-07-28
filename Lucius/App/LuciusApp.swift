import SwiftUI
import SwiftData

/// Features that are implemented but not ready to expose in the app yet.
enum AppFeatures {
    static let imageGenerationEnabled = false
}

@main
struct LuciusApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var router = AppRouter()
    @State private var loadingCoordinator = AppLoadingCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer

    init() {
        // Reminders are on by default until the user turns them off in Settings.
        UserDefaults.standard.register(defaults: [
            AppSettingsKeys.notificationsEnabled: true,
            AppSettingsKeys.learningLanguageCode: SupportedLanguage.systemLanguage.rawValue,
        ])

        modelContainer = ModelContainerFactory.make()

        // Lets image generation finish and save even after leaving the screen.
        SceneImageGenerationManager.shared.configure(with: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if hasSeenWelcome || OnboardingStore.hasCompleted {
                        MainTabView()
                    } else {
                        OnboardingView {
                            withAnimation(.easeOut) {
                                hasSeenWelcome = true
                            }
                        }
                    }
                }

                if loadingCoordinator.isShowing {
                    LoadingView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(router)
            .animation(.easeInOut(duration: 0.25), value: loadingCoordinator.isShowing)
            .onOpenURL { url in
                hasSeenWelcome = true // a deep link implies onboarding is done
                OnboardingStore.complete()
                router.handle(url)
            }
            .task {
                await loadingCoordinator.finishPreparation()
                WidgetSync.update(context: modelContainer.mainContext)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                loadingCoordinator.beginPreparation()
                Task {
                    await loadingCoordinator.finishPreparation()
                    WidgetSync.update(context: modelContainer.mainContext)
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
