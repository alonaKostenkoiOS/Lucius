import SwiftUI

/// The three review answers: I forgot / Almost / I know it.
/// Used on both the word detail and the review screens.
struct ReviewAnswerButtons: View {
    let onAnswer: (ReviewAnswer) -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            answerButton("I forgot", tint: .answerForgot, answer: .forgot, hint: "Resets this word to review again soon")
            answerButton("Almost", tint: .answerAlmost, answer: .almost, hint: "You nearly remembered it")
            answerButton("I know it", tint: .answerKnow, answer: .knowIt, hint: "You recalled it confidently")
        }
    }

    private func answerButton(_ title: String, tint: Color, answer: ReviewAnswer, hint: String) -> some View {
        Button {
            haptic(for: answer)
            onAnswer(answer)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg - 2)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    private func haptic(for answer: ReviewAnswer) {
        switch answer {
        case .forgot: Haptics.warning()
        case .almost: Haptics.tap()
        case .knowIt: Haptics.impact()
        }
    }
}

#Preview {
    ReviewAnswerButtons { _ in }
        .padding()
        .background(Color.appBackground)
}
