import SwiftUI

/// A small round button that pronounces text in its learning language.
struct SpeakButton: View {
    let text: String
    var languageCode: String = AppLanguageSettings.learningLanguageCode

    var body: some View {
        Button {
            Haptics.tap()
            SpeechService.shared.speak(text, languageCode: languageCode)
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
