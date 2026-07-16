import AVFoundation

/// Pronounces words using the voice for their learning language.
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// Listening exercises are offered only when iOS has a voice for the language.
    func isAvailable(languageCode: String) -> Bool {
        AVSpeechSynthesisVoice(language: languageCode) != nil
            || AVSpeechSynthesisVoice(language: Locale(identifier: languageCode).identifier) != nil
    }

    func speak(_ text: String, languageCode: String = AppLanguageSettings.learningLanguageCode) {
        // Make pronunciation audible even when the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: Locale(identifier: languageCode).identifier)
        utterance.rate = 0.45

        synthesizer.speak(utterance)
    }
}
