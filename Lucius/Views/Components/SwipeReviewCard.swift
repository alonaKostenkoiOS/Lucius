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
        .padding(Spacing.xxl)
        .background {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.cardBackground)
                .elevation(.card)
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
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                Text(word.word)
                    .font(.heroWord)
                    .multilineTextAlignment(.center)
                SpeakButton(text: word.word)
            }

            Label("Tap to reveal", systemImage: "hand.tap")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var back: some View {
        // Counter-flip so the back reads correctly after the 3D rotation.
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Text(word.word)
                    .font(.cardWord)
                SpeakButton(text: word.word)
            }

            Divider()

            Text(word.translation)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            if let example = word.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let visualAssociation = word.visualAssociation {
                VisualSceneCard(text: visualAssociation)
            }

            if let sceneImageData = word.sceneImageData {
                SceneImageView(imageData: sceneImageData, height: 180)
            }

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
