import SwiftUI

/// Root navigation: Home, Review and Settings tabs.
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "rectangle.stack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(.lavender)
        // The palette is built for a light, airy look — keep it
        // consistent even when the device is in dark mode.
        .preferredColorScheme(.light)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: VocabularyWord.self, inMemory: true)
}
