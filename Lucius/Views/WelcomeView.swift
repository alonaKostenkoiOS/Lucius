import SwiftUI

/// Backward-compatible wrapper around the new onboarding welcome screen.
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingWelcomeScreen(onContinue: onContinue)
    }
}

#Preview {
    WelcomeView {}
}
