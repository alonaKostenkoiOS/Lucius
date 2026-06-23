import SwiftUI

/// A small round button that pronounces the given English text.
struct SpeakButton: View {
    let text: String

    var body: some View {
        Button {
            Haptics.tap()
            SpeechService.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .padding(10)
                .background(Color.lavenderSoft)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pronounce word")
    }
}

#Preview {
    SpeakButton(text: "serendipity")
        .padding()
        .background(Color.appBackground)
}
