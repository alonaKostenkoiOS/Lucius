import SwiftUI

/// First-launch welcome screen: the full-bleed Lucius poster
/// with a single call to action.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("WelcomePoster")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            Button(action: onContinue) {
                Text("Get started")
                    .font(.headline)
                    .foregroundStyle(Color.deepPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    WelcomeView {}
}
