import SwiftUI
import ImagePlayground

/// "Generate scene image" button.
///
/// Prefers on-device Apple Image Playground (iOS 18.2+, Apple Intelligence
/// devices). Everywhere else it falls back to free network generation,
/// so the button is always available.
struct SceneImageGenerationButton: View {
    let word: VocabularyWord
    let title: String
    let isGenerating: Bool
    var etaSeconds: Int?
    let onPlaygroundImage: (URL) -> Void
    let onNetworkGenerate: () -> Void

    var body: some View {
        if #available(iOS 18.2, *) {
            PlaygroundGenerationButton(
                word: word,
                title: title,
                isGenerating: isGenerating,
                etaSeconds: etaSeconds,
                onPlaygroundImage: onPlaygroundImage,
                onNetworkGenerate: onNetworkGenerate
            )
        } else {
            NetworkGenerationButton(
                title: title,
                isGenerating: isGenerating,
                etaSeconds: etaSeconds,
                action: onNetworkGenerate
            )
        }
    }
}

/// On-device generation via the system Image Playground sheet,
/// with the network fallback for devices without Apple Intelligence.
@available(iOS 18.2, *)
private struct PlaygroundGenerationButton: View {
    let word: VocabularyWord
    let title: String
    let isGenerating: Bool
    var etaSeconds: Int?
    let onPlaygroundImage: (URL) -> Void
    let onNetworkGenerate: () -> Void

    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var isPlaygroundPresented = false

    var body: some View {
        if supportsImagePlayground {
            Button {
                isPlaygroundPresented = true
            } label: {
                GenerationButtonLabel(title: title, isGenerating: false)
            }
            .imagePlaygroundSheet(
                isPresented: $isPlaygroundPresented,
                concepts: concepts
            ) { url in
                onPlaygroundImage(url)
            }
        } else {
            NetworkGenerationButton(
                title: title,
                isGenerating: isGenerating,
                etaSeconds: etaSeconds,
                action: onNetworkGenerate
            )
        }
    }

    /// The visual association is the best prompt; fall back to the word itself.
    private var concepts: [ImagePlaygroundConcept] {
        if let visualAssociation = word.visualAssociation {
            [.extracted(from: visualAssociation, title: word.word)]
        } else {
            [.text(word.word)]
        }
    }
}

/// Free network generation with a progress state while the image loads.
private struct NetworkGenerationButton: View {
    let title: String
    let isGenerating: Bool
    var etaSeconds: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GenerationButtonLabel(title: title, isGenerating: isGenerating, etaSeconds: etaSeconds)
        }
        .disabled(isGenerating)
    }
}

private struct GenerationButtonLabel: View {
    let title: String
    let isGenerating: Bool
    var etaSeconds: Int?

    private var generatingText: String {
        if let etaSeconds, etaSeconds > 0 {
            "Generating… ~\(etaSeconds)s"
        } else {
            "Generating…"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if isGenerating {
                ProgressView()
                    .tint(Color.lavender)
                Text(generatingText)
                    .monospacedDigit()
            } else {
                Image(systemName: "wand.and.stars")
                Text(title)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.lavender)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.lavenderSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
