import SwiftUI

struct ContextReviewPromptCard<Content: View>: View {
    let question: ContextReviewQuestion
    let title: String
    let systemImage: String
    let instruction: String
    let content: Content

    init(
        question: ContextReviewQuestion,
        title: String? = nil,
        systemImage: String? = nil,
        instruction: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.question = question
        self.title = title ?? question.mode.title
        self.systemImage = systemImage ?? Self.icon(for: question.mode)
        self.instruction = instruction ?? question.mode.instruction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.deepPurple)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.lavenderSoft, in: Capsule())
                Spacer()
                if question.mode == .use {
                    SpeakButton(text: question.correctAnswer, languageCode: question.word.languageCode)
                }
            }

            Text(instruction)
                .font(.headline)
                .foregroundStyle(.secondary)

            content
        }
        .padding(Spacing.xl)
        .cardStyle()
    }

    private static func icon(for mode: ContextReviewMode) -> String {
        switch mode {
        case .recognize: "eye"
        case .recall: "keyboard"
        case .use: "square.and.pencil"
        }
    }
}

struct RecognitionOptionsView: View {
    let options: [String]
    let correctAnswer: String
    let selectedAnswer: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: Spacing.md) {
                        Text(String(UnicodeScalar(65 + index)!))
                            .font(.caption.bold())
                            .frame(width: 30, height: 30)
                            .background(Color.lavenderSoft, in: Circle())
                        Text(option)
                            .font(.headline)
                        Spacer()
                        if let symbol = resultSymbol(for: option) {
                            Image(systemName: symbol.name)
                                .foregroundStyle(symbol.color)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(Spacing.md)
                    .background(background(for: option))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(border(for: option), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedAnswer != nil)
            }
        }
    }

    private func isCorrect(_ option: String) -> Bool {
        ContextReviewText.answersMatch(option, correctAnswer)
    }

    private func background(for option: String) -> Color {
        guard let selectedAnswer else { return .appBackground }
        if isCorrect(option) { return .answerKnow.opacity(0.12) }
        if option == selectedAnswer { return .answerForgot.opacity(0.1) }
        return .appBackground
    }

    private func border(for option: String) -> Color {
        guard let selectedAnswer else { return .lavender.opacity(0.18) }
        if isCorrect(option) { return .answerKnow }
        if option == selectedAnswer { return .answerForgot }
        return .clear
    }

    private func resultSymbol(for option: String) -> (name: String, color: Color)? {
        guard let selectedAnswer else { return nil }
        if isCorrect(option) { return ("checkmark.circle.fill", .answerKnow) }
        if option == selectedAnswer { return ("xmark.circle.fill", .answerForgot) }
        return nil
    }
}

struct ContextReviewFeedbackCard: View {
    let feedback: ContextReviewFeedback
    let mode: ContextReviewMode

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Label(
                feedback.isCorrect ? "Correct" : "Keep learning",
                systemImage: feedback.isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"
            )
            .font(.title3.bold())
            .foregroundStyle(feedback.isCorrect ? Color.answerKnow : Color.answerForgot)

            if mode == .recall, !feedback.isCorrect {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your answer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    RecallMistakeText(
                        submitted: feedback.submittedAnswer,
                        correct: feedback.correctAnswer
                    )
                }
            }

            FeedbackRow(title: "Correct answer", systemImage: "checkmark", text: feedback.correctAnswer)
            if let originalSentence = feedback.originalSentence {
                FeedbackRow(title: "Original sentence", systemImage: "text.quote", text: originalSentence)
            }
            if let translation = feedback.translation {
                FeedbackRow(title: "Translation", systemImage: "character.book.closed", text: translation)
            }
            if let explanation = feedback.explanation {
                FeedbackRow(title: "Why it fits", systemImage: "lightbulb", text: explanation)
            }
            if let memoryTip = feedback.memoryTip {
                FeedbackRow(title: "Memory tip", systemImage: "sparkles", text: memoryTip)
            }
        }
        .padding(Spacing.xl)
        .background(
            feedback.isCorrect ? Color.answerKnow.opacity(0.07) : Color.answerForgot.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    (feedback.isCorrect ? Color.answerKnow : Color.answerForgot).opacity(0.25),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct FeedbackRow: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .textCase(.uppercase)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RecallMistakeText: View {
    let submitted: String
    let correct: String

    var body: some View {
        highlighted
            .font(.title3.monospaced().weight(.semibold))
            .accessibilityLabel("You entered \(submitted). Correct answer: \(correct)")
    }

    private var highlighted: Text {
        let entered = Array(submitted)
        let answer = Array(correct)
        guard !entered.isEmpty else {
            return Text("No answer").foregroundColor(.answerForgot)
        }

        return entered.enumerated().reduce(Text("")) { result, pair in
            let (index, character) = pair
            let matches = index < answer.count
                && String(character).localizedCaseInsensitiveCompare(String(answer[index])) == .orderedSame
            let segment = Text(String(character))
                .foregroundColor(matches ? .primary : .answerForgot)
                .underline(!matches, color: .answerForgot)
            return result + segment
        }
    }
}

#Preview("Context Review — Demo") {
    ZStack {
        AppBackgroundGradient()
        ScrollView {
            ContextReviewPromptCard(question: .demo) {
                Text(ContextReviewQuestion.demo.clozeSentence ?? "")
                    .font(.title2.weight(.semibold))
                RecognitionOptionsView(
                    options: ContextReviewQuestion.demo.options,
                    correctAnswer: ContextReviewQuestion.demo.correctAnswer,
                    selectedAnswer: nil,
                    onSelect: { _ in }
                )
            }
            .padding()
        }
    }
}
