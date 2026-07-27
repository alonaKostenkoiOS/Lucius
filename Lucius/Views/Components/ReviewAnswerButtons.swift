import SwiftUI

/// The three review answers: I forgot / Almost / I know it.
/// Used on both the word detail and the review screens.
struct ReviewAnswerButtons: View {
    let onAnswer: (ReviewAnswer) -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            answerButton(String(localized: "review.answer.forgot"), tint: .answerForgot, answer: .forgot, hint: String(localized: "review.answer.forgot_hint"))
            answerButton(String(localized: "review.answer.almost"), tint: .answerAlmost, answer: .almost, hint: String(localized: "review.answer.almost_hint"))
            answerButton(String(localized: "review.answer.know"), tint: .answerKnow, answer: .knowIt, hint: String(localized: "review.answer.know_hint"))
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
