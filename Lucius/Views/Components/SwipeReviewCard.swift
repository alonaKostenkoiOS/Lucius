import SwiftUI

/// The heart of the review experience: a large card that flips in 3D to
/// reveal the answer, then can be swiped like a flashcard —
/// left = forgot, right = I know it, up = almost.
///
/// The three answer buttons below remain the accessible path; swiping is
/// the delightful shortcut for sighted users.
struct SwipeReviewCard: View {
    let word: VocabularyWord
    @Binding var isRevealed: Bool
    let onAnswer: (ReviewAnswer) -> Void

    @State private var drag: CGSize = .zero
    @State private var isGone = false
    /// Tracks whether the drag has crossed the commit threshold, so we
    /// only fire the selection haptic once per crossing.
    @State private var armed = false
    /// Set once an answer is committed so a second swipe can't double-answer
    /// during the brief fly-out animation.
    @State private var committed = false
    @State private var isMemoryCueExpanded = false

    private let threshold: CGFloat = 110

    var body: some View {
        ZStack {
            cardFace
        }
        .offset(drag)
        .rotationEffect(.degrees(Double(drag.width / 18)))
        .scaleEffect(isGone ? 0.85 : 1)
        .opacity(isGone ? 0 : 1)
        .gesture(isRevealed && !committed ? swipeGesture : nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: drag)
        .animation(.easeOut(duration: 0.25), value: isGone)
    }

    // MARK: - Card faces (3D flip)

    private var cardFace: some View {
        ZStack {
            front
                .opacity(isRevealed ? 0 : 1)

            // `back` carries a static 180° counter-rotation, so once the
            // container flips to 180° the text reads the right way round.
            back
                .opacity(isRevealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 410)
        .padding(Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.lavenderSoft.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .elevation(.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.lavender.opacity(0.14), lineWidth: 1)
        }
        .overlay(swipeOverlay)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .rotation3DEffect(.degrees(isRevealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isRevealed)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRevealed {
                Haptics.tap()
                isRevealed = true
            }
        }
    }

    private var front: some View {
        VStack(spacing: Spacing.xl) {
            VocabularyCardEyebrow(word: word)

            Spacer(minLength: Spacing.md)

            VStack(spacing: Spacing.md) {
                Text(word.word)
                    .font(.heroWord)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(Color.deepPurple)

                SpeakButton(text: word.word, languageCode: word.languageCode)
            }

            if let clue = VocabularyCardText.cloze(example: word.example, word: word.word) {
                VocabularyContextBlock(text: clue, highlightedWord: nil, style: .clue)
            }

            Spacer(minLength: Spacing.sm)

            Label("Tap to reveal meaning", systemImage: "hand.tap")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.lavender)
        }
    }

    private var back: some View {
        // Counter-flip so the back reads correctly after the 3D rotation.
        VStack(spacing: Spacing.lg) {
            VocabularyCardEyebrow(word: word)

            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Text(word.word)
                        .font(.cardWord)
                        .foregroundStyle(Color.deepPurple)
                    SpeakButton(text: word.word, languageCode: word.languageCode)
                }

                Text(word.translation)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }

            if let example = word.example {
                VocabularyContextBlock(
                    text: example,
                    highlightedWord: word.word,
                    style: .answer
                )
            }

            VocabularyMemoryCueDisclosure(
                visualAssociation: word.visualAssociation,
                imageData: word.sceneImageData,
                isExpanded: $isMemoryCueExpanded
            )

            Label("Swipe ← forgot · → know it · ↑ almost", systemImage: "hand.draw")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xs)
        }
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Swipe affordance

    /// The answer the current drag points toward, if past a small dead zone.
    private var candidate: ReviewAnswer? {
        let horizontal = abs(drag.width)
        let up = -drag.height
        if horizontal < 30 && up < 30 { return nil }
        if up > horizontal { return .almost }
        return drag.width > 0 ? .knowIt : .forgot
    }

    @ViewBuilder
    private var swipeOverlay: some View {
        if let candidate, isRevealed {
            let progress = min(dragMagnitude / threshold, 1)
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(tint(for: candidate).opacity(0.18 * progress))
                .overlay(alignment: overlayAlignment(for: candidate)) {
                    Text(label(for: candidate))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(tint(for: candidate))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(Spacing.xl)
                        .opacity(progress)
                }
                .allowsHitTesting(false)
        }
    }

    private var dragMagnitude: CGFloat { max(abs(drag.width), abs(drag.height)) }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                let past = dragMagnitude >= threshold
                if past != armed {
                    armed = past
                    if past { Haptics.selection() }
                }
            }
            .onEnded { _ in
                guard let candidate, dragMagnitude >= threshold else {
                    withAnimation { drag = .zero }
                    armed = false
                    return
                }
                commit(candidate)
            }
    }

    private func commit(_ answer: ReviewAnswer) {
        guard !committed else { return }
        committed = true
        armed = false
        // Fling the card off in the drag direction, then notify.
        let flyOut: CGSize
        switch answer {
        case .knowIt: flyOut = CGSize(width: 600, height: drag.height)
        case .forgot: flyOut = CGSize(width: -600, height: drag.height)
        case .almost: flyOut = CGSize(width: drag.width, height: -700)
        }
        withAnimation(.easeOut(duration: 0.25)) {
            drag = flyOut
            isGone = true
        }
        // Let the card finish flying off before the parent swaps in the next word.
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            onAnswer(answer)
        }
    }

    private func tint(for answer: ReviewAnswer) -> Color {
        switch answer {
        case .forgot: .answerForgot
        case .almost: .answerAlmost
        case .knowIt: .answerKnow
        }
    }

    private func label(for answer: ReviewAnswer) -> String {
        switch answer {
        case .forgot: "Forgot"
        case .almost: "Almost"
        case .knowIt: "I know it!"
        }
    }

    private func overlayAlignment(for answer: ReviewAnswer) -> Alignment {
        switch answer {
        case .forgot: .topLeading
        case .knowIt: .topTrailing
        case .almost: .top
        }
    }
}

// MARK: - Reusable vocabulary presentation

/// Pure text transformations used by card views and unit tests.
enum VocabularyCardText {
    static func cloze(example: String?, word: String) -> String? {
        ContextReviewText.cloze(sentence: example, word: word)
    }

    static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}

/// Small, reusable orientation row used by review and detail cards.
struct VocabularyCardEyebrow: View {
    let word: VocabularyWord

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Label(
                AppLanguageSettings.displayName(for: word.languageCode),
                systemImage: "globe"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.lavender)
            .lineLimit(1)

            Spacer(minLength: Spacing.sm)

            StatusBadge(status: word.reviewStatus)
        }
    }
}

struct VocabularyContextBlock: View {
    enum Style: Equatable {
        case clue
        case answer
    }

    let text: String
    let highlightedWord: String?
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(
                style == .clue ? "Context clue" : "In context",
                systemImage: style == .clue ? "lightbulb" : "text.quote"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(style == .clue ? Color.orange : Color.lavender)
            .textCase(.uppercase)

            Group {
                if let highlightedWord {
                    HighlightedVocabularyText(text: text, word: highlightedWord)
                } else {
                    Text("\u{201C}\(text)\u{201D}")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(style == .clue ? 3 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            style == .clue ? Color.orange.opacity(0.08) : Color.lavenderSoft.opacity(0.72)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Highlights the learned term inside a naturally wrapping sentence.
private struct HighlightedVocabularyText: View {
    let text: String
    let word: String

    var body: some View {
        if let range = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
            let before = String(text[..<range.lowerBound])
            let match = String(text[range])
            let after = String(text[range.upperBound...])

            (Text("\u{201C}\(before)")
                + Text(match).bold().foregroundColor(.deepPurple)
                + Text("\(after)\u{201D}"))
        } else {
            Text("\u{201C}\(text)\u{201D}")
        }
    }
}

/// Optional imagery stays out of the way until the learner asks for a memory cue.
struct VocabularyMemoryCueDisclosure: View {
    let visualAssociation: String?
    let imageData: Data?
    var associationLineLimit: Int? = 3
    var imageHeight: CGFloat = 110
    @Binding var isExpanded: Bool

    private var association: String? {
        VocabularyCardText.cleaned(visualAssociation)
    }

    var body: some View {
        if association != nil || imageData != nil {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: Spacing.md) {
                    if let association {
                        VisualSceneCard(text: association, lineLimit: associationLineLimit)
                    }
                    if let imageData {
                        SceneImageView(imageData: imageData, height: imageHeight)
                    }
                }
                .padding(.top, Spacing.md)
            } label: {
                Label("Memory cue", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.deepPurple)
            }
            .padding(Spacing.md)
            .background(Color.lavenderSoft.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}
