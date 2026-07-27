import SwiftUI

/// Artwork-only loading surface used by the application root.
struct LoadingView: View {
    var body: some View {
        ZStack {
            // Keeps the transition visually stable if the asset catalog is
            // still being decoded on the very first frame.
            Color(red: 0.98, green: 0.91, blue: 0.87)

            Image("WelcomePoster", bundle: .main)
                .resizable()
                .scaledToFill()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    LoadingView()
}
