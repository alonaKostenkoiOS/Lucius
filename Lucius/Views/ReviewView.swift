import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var learningLanguageCode = "en"
    @State private var viewModel = ReviewViewModel()
    @State private var selectedModes: Set<ReviewPracticeMode>
    @State private var sessionStarted = false
    @State private var typedAnswer = ""
    @State private var usageSentence = ""
    @State private var flashcardRevealed = false
    @FocusState private var focusedField: InputField?

    private enum InputField { case answer, usage }

    init() {
        let audioAvailable = SpeechService.shared.isAvailable(
            languageCode: AppLanguageSettings.learningLanguageCode
        )
        _selectedModes = State(
            initialValue: ReviewModePreferences.load(audioAvailable: audioAvailable)
        )
    }

    private var audioAvailable: Bool {
        SpeechService.shared.isAvailable(languageCode: learningLanguageCode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                if !sessionStarted {
                    ReviewModeSelectionView(
                        selection: $selectedModes,
                        audioAvailable: audioAvailable,
                        onStart: startSession
                    )
                } else if let word = viewModel.currentWord,
                          let mode = viewModel.currentPracticeMode {
                    if mode == .flashcards {
                        flashcardReview(word)
                    } else if let question = viewModel.currentQuestion {
                        exerciseReview(question, mode: mode)
                    }
                } else {
                    completedState
                }

                CelebrationView(isActive: $viewModel.celebrate)
            }
            .navigationTitle(sessionStarted ? "Review" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sessionStarted {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Modes", systemImage: "slider.horizontal.3") {
                            endSession()
                        }
                    }
                }
            }
            .onChange(of: viewModel.currentWord?.id) { _, _ in resetInputs() }
            .onChange(of: learningLanguageCode) { _, _ in
                guard !sessionStarted else { return }
                selectedModes = ReviewModePreferences.load(audioAvailable: audioAvailable)
            }
        }
        .tint(.lavender)
    }

    private func flashcardReview(_ word: VocabularyWord) -> some View {
        VStack(spacing: Spacing.xl) {
            sessionHeader
            Spacer(minLength: 0)
            SwipeReviewCard(word: word, isRevealed: $flashcardRevealed) {
                viewModel.answerFlashcard($0, context: modelContext)
            }
            .id(word.id)
            Spacer(minLength: 0)

            if flashcardRevealed {
                VStack(spacing: Spacing.sm) {
                    ReviewAnswerButtons {
                        viewModel.answerFlashcard($0, context: modelContext)
                    }
                    Text("or swipe the card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                PrimaryButton(title: "Show answer", systemImage: "eye") {
                    withAnimation { flashcardRevealed = true }
                }
            }
        }
        .padding(Spacing.xl)
    }

    private func exerciseReview(
        _ question: ContextReviewQuestion,
        mode: ReviewPracticeMode
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    sessionHeader
                    exerciseCard(question, mode: mode)

                    if let feedback = viewModel.feedback {
                        ContextReviewFeedbackCard(feedback: feedback, mode: question.mode)
                            .id("feedback")

                        PrimaryButton(title: "Continue", systemImage: "arrow.right") {
                            focusedField = nil
                            withAnimation { viewModel.continueReview() }
                        }
                    }
                }
                .padding(Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.hasSubmittedAnswer) { _, submitted in
                guard submitted else { return }
                focusedField = nil
                withAnimation { proxy.scrollTo("feedback", anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func exerciseCard(
        _ question: ContextReviewQuestion,
        mode: ReviewPracticeMode
    ) -> some View {
        ContextReviewPromptCard(
            question: question,
            title: mode.title,
            systemImage: mode.systemImage,
            instruction: mode.description
        ) {
            switch mode {
            case .cloze:
                sentencePrompt(question)
                translationHint(question)
                answerField(placeholder: "Missing word")

            case .multipleChoice:
                wordHeading(question.correctAnswer)
                RecognitionOptionsView(
                    options: viewModel.answerOptions,
                    correctAnswer: question.translation ?? question.correctAnswer,
                    selectedAnswer: viewModel.feedback?.submittedAnswer,
                    onSelect: { viewModel.submitChoice($0, context: modelContext) }
                )

            case .typeWord:
                if let translation = question.translation {
                    VStack(spacing: Spacing.sm) {
                        Text("Meaning")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.lavender)
                            .textCase(.uppercase)
                        Text(translation)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                answerField(placeholder: "Type the word")

            case .listening:
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.lavender)
                    Button {
                        speak(question)
                    } label: {
                        Label("Play again", systemImage: "speaker.wave.2.fill")
                            .font(.headline)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.md)
                            .background(Color.lavenderSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .task(id: question.id) { speak(question) }

                RecognitionOptionsView(
                    options: viewModel.answerOptions,
                    correctAnswer: question.correctAnswer,
                    selectedAnswer: viewModel.feedback?.submittedAnswer,
                    onSelect: { viewModel.submitChoice($0, context: modelContext) }
                )

            case .useSentence:
                wordHeading(question.correctAnswer)
                if let translation = question.translation {
                    Text(translation)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                TextField(
                    "Write a sentence containing \(question.correctAnswer)…",
                    text: $usageSentence,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .focused($focusedField, equals: .usage)
                .disabled(viewModel.hasSubmittedAnswer)
                .padding(Spacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                if !viewModel.hasSubmittedAnswer {
                    PrimaryButton(
                        title: "Save sentence",
                        systemImage: "square.and.arrow.down",
                        isEnabled: ContextReviewText.cleaned(usageSentence) != nil
                    ) {
                        viewModel.submitUsage(usageSentence, context: modelContext)
                    }
                }

            case .flashcards, .mixed:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func answerField(placeholder: String) -> some View {
        TextField(placeholder, text: $typedAnswer)
            .font(.title3.weight(.semibold))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($focusedField, equals: .answer)
            .disabled(viewModel.hasSubmittedAnswer)
            .onSubmit(submitTypedAnswer)
            .padding(Spacing.md)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

        if !viewModel.hasSubmittedAnswer {
            PrimaryButton(
                title: "Check answer",
                systemImage: "checkmark",
                isEnabled: ContextReviewText.cleaned(typedAnswer) != nil,
                action: submitTypedAnswer
            )
        }
    }

    private func sentencePrompt(_ question: ContextReviewQuestion) -> some View {
        Text(question.clozeSentence ?? "")
            .font(.title2.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Sentence with a missing word: \(question.clozeSentence ?? "")")
    }

    @ViewBuilder
    private func translationHint(_ question: ContextReviewQuestion) -> some View {
        if let translation = question.translation {
            Label(translation, systemImage: "character.book.closed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.deepPurple)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lavenderSoft.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private func wordHeading(_ word: String) -> some View {
        Text(word)
            .font(.heroWord)
            .foregroundStyle(Color.deepPurple)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var sessionHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("\(viewModel.remainingCount) left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let mode = viewModel.currentPracticeMode {
                    Label(mode.title, systemImage: mode.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.deepPurple)
                }
            }
            ProgressView(value: viewModel.sessionProgress)
                .tint(.lavender)
        }
        .accessibilityElement(children: .combine)
    }

    private var completedState: some View {
        VStack(spacing: Spacing.xl) {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "All caught up",
                message: "No words to review right now. Come back when a reminder arrives."
            )
            PrimaryButton(title: "Change review modes", systemImage: "slider.horizontal.3") {
                endSession()
            }
        }
        .padding(Spacing.xl)
    }

    private func startSession() {
        ReviewModePreferences.save(selectedModes)
        viewModel.loadDueWords(
            context: modelContext,
            selectedModes: selectedModes,
            audioAvailable: audioAvailable
        )
        sessionStarted = true
    }

    private func endSession() {
        focusedField = nil
        sessionStarted = false
    }

    private func submitTypedAnswer() {
        viewModel.submitTypedAnswer(typedAnswer, context: modelContext)
    }

    private func speak(_ question: ContextReviewQuestion) {
        SpeechService.shared.speak(
            question.correctAnswer,
            languageCode: question.word.languageCode
        )
    }

    private func resetInputs() {
        typedAnswer = ""
        usageSentence = ""
        flashcardRevealed = false
        focusedField = nil
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
