import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var learningLanguageCode = "en"
    private let dailyFocusSession: DailyFocusSession?
    @State private var viewModel = ReviewViewModel()
    @State private var selectedModes: Set<ReviewPracticeMode>
    @State private var sessionStarted = false
    @State private var dailyFocusDidLoad = false
    @State private var typedAnswer = ""
    @State private var usageSentence = ""
    @State private var flashcardRevealed = false
    @FocusState private var focusedField: InputField?
    private let reviewWordID: UUID?

    private enum InputField { case answer, usage }

    init(dailyFocusSession: DailyFocusSession? = nil, reviewWordID: UUID? = nil) {
        self.dailyFocusSession = dailyFocusSession
        self.reviewWordID = reviewWordID
        let audioAvailable = SpeechService.shared.isAvailable(
            languageCode: AppLanguageSettings.learningLanguageCode
        )
        _selectedModes = State(
            initialValue: ReviewModePreferences.load(audioAvailable: audioAvailable)
        )
        _sessionStarted = State(initialValue: dailyFocusSession != nil || reviewWordID != nil)
    }

    private var audioAvailable: Bool {
        SpeechService.shared.isAvailable(languageCode: learningLanguageCode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                if isDailyFocus && !dailyFocusDidLoad {
                    ProgressView()
                        .tint(.lavender)
                } else if !sessionStarted {
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
            .navigationTitle(sessionStarted ? String(localized: "review.title") : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sessionStarted && !isDailyFocus {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("review.change_modes", systemImage: "slider.horizontal.3") {
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
            .task(id: reviewTaskID) {
                guard !dailyFocusDidLoad else { return }
                if isDailyFocus {
                    startDailyFocus()
                } else if let reviewWordID {
                    startTargetedReview(wordID: reviewWordID)
                }
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
                    Text("review.swipe_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                PrimaryButton(title: String(localized: "review.show_answer"), systemImage: "eye") {
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

                        PrimaryButton(title: String(localized: "common.continue"), systemImage: "arrow.right") {
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
                answerField(placeholder: String(localized: "review.missing_word"))

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
                        Text("review.meaning")
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
                            Label("review.play_again", systemImage: "speaker.wave.2.fill")
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
                    String(format: String(localized: "review.use_sentence_placeholder"), question.correctAnswer),
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
                        title: String(localized: "review.save_sentence"),
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
                title: String(localized: "review.check_answer"),
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
            .accessibilityLabel(String(format: String(localized: "accessibility.missing_sentence"), question.clozeSentence ?? ""))
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
                Text(String(format: String(localized: "review.words_remaining"), viewModel.remainingCount))
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
        if let dailyFocusSession {
            return AnyView(
                DailyFocusSummaryView(session: dailyFocusSession) {
                    dismiss()
                }
            )
        }

        return AnyView(
        VStack(spacing: Spacing.xl) {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: String(localized: "review.all_caught_up.title"),
                message: String(localized: "review.all_caught_up.subtitle")
            )
            PrimaryButton(title: String(localized: "review.change_modes"), systemImage: "slider.horizontal.3") {
                endSession()
            }
        }
        .padding(Spacing.xl)
        )
    }

    private var isDailyFocus: Bool { dailyFocusSession != nil }

    private var reviewTaskID: UUID? {
        dailyFocusSession?.id ?? reviewWordID
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

    private func startDailyFocus() {
        let result = DailyFocusService.loadOrCreate(context: modelContext)
        guard let session = result.session, !result.words.isEmpty else {
            dailyFocusDidLoad = true
            return
        }
        let pendingWords = result.words.filter { !session.completedIDs.contains($0.id) }
        guard !pendingWords.isEmpty else {
            dailyFocusDidLoad = true
            return
        }

        viewModel.onItemCompleted = { wordID, isCorrect in
            DailyFocusService.record(
                wordID: wordID,
                isCorrect: isCorrect,
                session: session,
                context: modelContext
            )
        }
        viewModel.loadWords(
            pendingWords,
            selectedModes: [.mixed],
            audioAvailable: audioAvailable,
            modeSequence: DailyFocusService.modeSequence(audioAvailable: audioAvailable),
            modeSequenceOffset: session.completedIDs.intersection(Set(session.wordIDs)).count
        )
        dailyFocusDidLoad = true
    }

    private func startTargetedReview(wordID: UUID) {
        let allWords = (try? modelContext.fetch(FetchDescriptor<VocabularyWord>())) ?? []
        let languageWords = allWords.filter { $0.languageCode == learningLanguageCode }

        if let word = languageWords.first(where: { $0.id == wordID }) {
            viewModel.loadWords(
                [word],
                vocabulary: languageWords,
                selectedModes: ReviewModePreferences.load(audioAvailable: audioAvailable),
                audioAvailable: audioAvailable
            )
        } else {
            // The word may have been deleted after the widget timeline was
            // generated. Reuse Daily Focus' local priority rules to open the
            // next eligible word instead of failing.
            if let fallback = DailyFocusService
                .selectWords(from: languageWords, now: .now)
                .first {
                viewModel.loadWords(
                    [fallback],
                    vocabulary: languageWords,
                    selectedModes: ReviewModePreferences.load(audioAvailable: audioAvailable),
                    audioAvailable: audioAvailable
                )
            } else {
                viewModel.loadDueWords(
                    context: modelContext,
                    selectedModes: ReviewModePreferences.load(audioAvailable: audioAvailable),
                    audioAvailable: audioAvailable
                )
            }
        }
        dailyFocusDidLoad = true
    }

    private func endSession() {
        focusedField = nil
        if isDailyFocus {
            dismiss()
            return
        }
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
