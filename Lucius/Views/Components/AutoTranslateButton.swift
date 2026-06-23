import SwiftUI
import Translation

/// "Translate" button for the add-word form.
///
/// Prefers the on-device system Translation framework (iOS 18+);
/// older devices fall back to a free network translation API.
struct AutoTranslateButton: View {
    let sourceText: String
    let onTranslation: (String) -> Void

    private var trimmedSource: String {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            AppleTranslationButton(sourceText: trimmedSource, onTranslation: onTranslation)
        } else {
            NetworkTranslationButton(sourceText: trimmedSource, onTranslation: onTranslation)
        }
    }
}

/// On-device translation. The system shows the language pack
/// download prompt automatically on first use.
@available(iOS 18.0, *)
private struct AppleTranslationButton: View {
    let sourceText: String
    let onTranslation: (String) -> Void

    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Button {
            if configuration == nil {
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: TranslationService.targetLanguageCode)
                )
            } else {
                // Re-fire the translation task for a new word.
                configuration?.invalidate()
            }
        } label: {
            TranslateButtonLabel(isTranslating: false)
        }
        .disabled(sourceText.isEmpty)
        .translationTask(configuration) { session in
            guard !sourceText.isEmpty else { return }
            if let response = try? await session.translate(sourceText) {
                onTranslation(response.targetText)
            }
        }
    }
}

/// Free network translation with a progress state.
private struct NetworkTranslationButton: View {
    let sourceText: String
    let onTranslation: (String) -> Void

    @State private var isTranslating = false

    var body: some View {
        Button {
            Task {
                isTranslating = true
                defer { isTranslating = false }
                if let translated = try? await TranslationService.shared.translate(sourceText) {
                    onTranslation(translated)
                }
            }
        } label: {
            TranslateButtonLabel(isTranslating: isTranslating)
        }
        .disabled(sourceText.isEmpty || isTranslating)
    }
}

private struct TranslateButtonLabel: View {
    let isTranslating: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isTranslating {
                ProgressView()
                    .tint(Color.lavender)
                Text("Translating…")
            } else {
                Image(systemName: "globe")
                Text("Translate")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.lavender)
    }
}
