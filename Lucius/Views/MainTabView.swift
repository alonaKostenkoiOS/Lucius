import SwiftUI

/// Root navigation: Home, Review and Settings tabs.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppRouter.Tab.home)

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "rectangle.stack")
                }
                .tag(AppRouter.Tab.review)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(.lavender)
        // The palette is built for a light, airy look — keep it
        // consistent even when the device is in dark mode.
        .preferredColorScheme(.light)
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter())
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
