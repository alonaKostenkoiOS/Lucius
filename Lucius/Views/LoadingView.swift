import SwiftUI

/// Artwork-only loading surface used by the application root.
struct LoadingView: View {
    var body: some View {
        Image("WelcomePoster")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    LoadingView()
}
