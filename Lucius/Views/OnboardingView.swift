import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                currentScreen
            }
            .toolbar {
                if viewModel.step.previous != nil, viewModel.step != .completion {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("common.back", systemImage: "chevron.left") {
                            withAnimation { viewModel.goBack() }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if viewModel.step != .welcome, viewModel.step != .completion {
                    ProgressView(value: progress)
                        .tint(.lavender)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, Spacing.sm)
                        .background(.regularMaterial)
                }
            }
        }
        .tint(.lavender)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.step)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch viewModel.step {
        case .welcome:
            OnboardingWelcomeScreen {
                withAnimation { viewModel.go(to: .languages) }
            }
        case .languages:
            OnboardingLanguageScreen(viewModel: viewModel) {
                withAnimation { viewModel.go(to: .discovery) }
            }
        case .discovery:
            OnboardingDiscoveryScreen(viewModel: viewModel, context: modelContext) {
                withAnimation { viewModel.go(to: .firstReview) }
            }
        case .firstReview:
            OnboardingFirstReviewScreen(viewModel: viewModel) {
                withAnimation { viewModel.go(to: .goals) }
            }
        case .goals:
            OnboardingMultiSelectScreen(
                stepLabel: String(format: String(localized: "onboarding.step"), 4),
                title: String(localized: "onboarding.goals.title"),
                subtitle: String(localized: "onboarding.goals.subtitle"),
                items: OnboardingGoal.allCases.map {
                    OnboardingChoice(id: $0.rawValue, title: $0.title, systemImage: $0.systemImage)
                },
                selectedIDs: Set(viewModel.goals.map(\.rawValue)),
                onToggle: { id in
                    if let goal = OnboardingGoal(rawValue: id) { viewModel.toggleGoal(goal) }
                },
                canContinue: !viewModel.goals.isEmpty
            ) {
                withAnimation { viewModel.go(to: .content) }
            }
        case .content:
            OnboardingMultiSelectScreen(
                stepLabel: String(format: String(localized: "onboarding.step"), 5),
                title: String(localized: "onboarding.content.title"),
                subtitle: String(localized: "onboarding.content.subtitle"),
                items: OnboardingContentSource.allCases.map {
                    OnboardingChoice(id: $0.rawValue, title: $0.title, systemImage: $0.systemImage)
                },
                selectedIDs: Set(viewModel.contentSources.map(\.rawValue)),
                onToggle: { id in
                    if let source = OnboardingContentSource(rawValue: id) { viewModel.toggleContent(source) }
                },
                canContinue: !viewModel.contentSources.isEmpty
            ) {
                withAnimation { viewModel.go(to: .level) }
            }
        case .level:
            OnboardingLevelScreen(viewModel: viewModel) {
                withAnimation { viewModel.go(to: .reviewModes) }
            }
        case .reviewModes:
            OnboardingReviewModesScreen(viewModel: viewModel) {
                withAnimation { viewModel.go(to: .notifications) }
            }
        case .notifications:
            OnboardingNotificationsScreen {
                withAnimation { viewModel.go(to: .completion) }
            }
        case .completion:
            OnboardingCompletionScreen {
                finishOnboarding()
            }
        }
    }

    private var progress: Double {
        let steps = OnboardingStep.allCases
        guard let index = steps.firstIndex(of: viewModel.step) else { return 0 }
        return Double(index) / Double(steps.count - 2)
    }

    private func finishOnboarding() {
        viewModel.complete()
        onComplete()
    }
}

struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "book.pages.fill")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(Color.lavender)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.md) {
                Text("onboarding.welcome.eyebrow")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.lavender)
                Text("onboarding.welcome.title")
                    .font(.appTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.deepPurple)
                Text("onboarding.welcome.subtitle")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
            PrimaryButton(title: String(localized: "onboarding.get_started"), systemImage: "arrow.right") {
                onContinue()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingLanguageScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            AppBackgroundGradient()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    OnboardingHeading(
                        stepLabel: String(format: String(localized: "onboarding.step"), 1),
                        title: String(localized: "onboarding.learning.title"),
                        subtitle: String(localized: "onboarding.learning.subtitle")
                    )
                    }

                    VStack(spacing: Spacing.md) {
                        OnboardingLanguageCard(
                            eyebrow: String(localized: "onboarding.learning.label"),
                            languageCode: viewModel.learningLanguageCode,
                            languages: viewModel.availableLanguages,
                            systemImage: "book.closed.fill",
                            tint: .lavender
                        ) { code in
                            viewModel.setLearningLanguage(code)
                        }

                        HStack(spacing: Spacing.md) {
                            Rectangle()
                                .fill(Color.lavender.opacity(0.18))
                                .frame(height: 1)
                            Button {
                                viewModel.swapLanguages()
                                Haptics.selection()
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.lavender)
                                    .frame(width: 38, height: 38)
                                    .background(Color.lavenderSoft, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "onboarding.language.swap"))
                            Rectangle()
                                .fill(Color.lavender.opacity(0.18))
                                .frame(height: 1)
                        }

                        OnboardingLanguageCard(
                            eyebrow: String(localized: "onboarding.native.label"),
                            languageCode: viewModel.nativeLanguageCode,
                            languages: viewModel.availableLanguages.filter { $0.code != viewModel.learningLanguageCode },
                            systemImage: "character.book.closed.fill",
                            tint: .deepPurple
                        ) { code in
                            viewModel.setNativeLanguage(code)
                        }
                    }

                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.lavender)
                        Text("onboarding.language.settings_hint")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.sm) {
                PrimaryButton(
                    title: String(localized: "common.continue"),
                    systemImage: "arrow.right",
                    isEnabled: viewModel.canContinueLanguages,
                    action: onContinue
                )
                .padding(.horizontal, Spacing.xl)
                Text("onboarding.language.pair_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.md)
            .background(.regularMaterial)
        }
    }
}

private struct OnboardingLanguageCard: View {
    let eyebrow: String
    let languageCode: String
    let languages: [LanguageOption]
    let systemImage: String
    let tint: Color
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(languages) { language in
                Button {
                    onSelect(language.code)
                } label: {
                    if language.code == languageCode {
                        Label(language.name, systemImage: "checkmark")
                    } else {
                        Text(language.name)
                    }
                }
            }
        } label: {
            HStack(spacing: Spacing.lg) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(AppLanguageSettings.displayName(for: languageCode))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        Text("onboarding.language.tap_to_change")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.lavender)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.1), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(eyebrow)
        .accessibilityValue(AppLanguageSettings.displayName(for: languageCode))
        .accessibilityHint(String(localized: "accessibility.language_picker_hint"))
    }
}

struct OnboardingDiscoveryScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: OnboardingViewModel
    let context: ModelContext
    let onContinue: () -> Void
    @State private var wordIsRevealed = false
    @State private var didSave = false

    private var demo: OnboardingDemoContent { viewModel.demo }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                OnboardingHeading(
                    stepLabel: String(format: String(localized: "onboarding.step"), 2),
                    title: String(localized: "onboarding.discovery.title"),
                    subtitle: String(localized: "onboarding.discovery.subtitle")
                )
                .padding(.horizontal, Spacing.xxl)

                VStack(alignment: .leading, spacing: Spacing.lg) {
                    OnboardingSentenceText(sentence: demo.sentence, word: demo.word, isHighlighted: wordIsRevealed) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            wordIsRevealed = true
                        }
                    }

                    if wordIsRevealed {
                        OnboardingVocabularyCard(content: demo, showsSaved: didSave)
                            .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Label(String(format: String(localized: "onboarding.discovery.tap_word"), demo.word), systemImage: "hand.tap")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.lavender)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(Spacing.lg)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .padding(.horizontal, Spacing.xl)
            }
            .padding(.top, Spacing.xl)
            .padding(.bottom, 110)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: didSave ? String(localized: "common.continue") : String(localized: "onboarding.discovery.save_word"),
                systemImage: didSave ? "arrow.right" : "plus",
                isEnabled: wordIsRevealed,
                action: save
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(.regularMaterial)
        }
        .onAppear { didSave = viewModel.demoWasSaved }
    }

    private func save() {
        if !didSave {
            guard viewModel.saveDemoWord(context: context) else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7)) { didSave = true }
            Haptics.success()
        } else {
            onContinue()
        }
    }
}

struct OnboardingFirstReviewScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    private var demo: OnboardingDemoContent { viewModel.demo }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                OnboardingHeading(
                    stepLabel: String(format: String(localized: "onboarding.step"), 3),
                    title: String(localized: "onboarding.review.title"),
                    subtitle: String(localized: "onboarding.review.subtitle")
                )

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(demo.clozeSentence)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    RecognitionOptionsView(
                        options: viewModel.reviewOptions,
                        correctAnswer: demo.word,
                        selectedAnswer: viewModel.reviewAnswer,
                        onSelect: { viewModel.submitReview($0) }
                    )

                    if viewModel.reviewSubmitted {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Label(
                                viewModel.reviewWasCorrect ? String(localized: "onboarding.review.correct") : String(format: String(localized: "onboarding.review.answer"), demo.word),
                                systemImage: viewModel.reviewWasCorrect ? "checkmark.circle.fill" : "lightbulb.fill"
                            )
                            .font(.headline)
                            .foregroundStyle(viewModel.reviewWasCorrect ? Color.answerKnow : Color.lavender)
                            Text(demo.sentence)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text("onboarding.review.context_tip")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.deepPurple)
                        }
                        .padding(Spacing.lg)
                        .background(Color.lavenderSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Spacing.xl)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            }
            .padding(Spacing.xl)
            .padding(.bottom, 110)
        }
        .onAppear { viewModel.prepareReviewOptions() }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: String(localized: "common.continue"),
                systemImage: "arrow.right",
                isEnabled: viewModel.reviewSubmitted,
                action: onContinue
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(.regularMaterial)
        }
    }
}

struct OnboardingMultiSelectScreen: View {
    let stepLabel: String
    let title: String
    let subtitle: String
    let items: [OnboardingChoice]
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void
    let canContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                OnboardingHeading(stepLabel: stepLabel, title: title, subtitle: subtitle)
                VStack(spacing: Spacing.md) {
                    ForEach(items) { item in
                        OnboardingChoiceRow(
                            title: item.title,
                            systemImage: item.systemImage,
                            isSelected: selectedIDs.contains(item.id),
                            action: { onToggle(item.id) }
                        )
                    }
                }
            }
            .padding(Spacing.xl)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: String(localized: "common.continue"), systemImage: "arrow.right", isEnabled: canContinue, action: onContinue)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(.regularMaterial)
        }
    }
}

struct OnboardingLevelScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                OnboardingHeading(
                    stepLabel: String(format: String(localized: "onboarding.step"), 6),
                    title: String(localized: "onboarding.level.title"),
                    subtitle: String(localized: "onboarding.level.subtitle")
                )
                VStack(spacing: Spacing.md) {
                    ForEach(OnboardingLevel.allCases) { level in
                        Button {
                            viewModel.selectLevel(level)
                            Haptics.selection()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(level.title)
                                        .font(.headline)
                                    if let cefr = level.approximateCEFR {
                                        Text(String(format: String(localized: "onboarding.level.approximate"), cefr))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: viewModel.level == level ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(viewModel.level == level ? Color.lavender : Color.secondary.opacity(0.35))
                            }
                            .foregroundStyle(.primary)
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewModel.level == level ? [.isSelected] : [])
                    }
                }
            }
            .padding(Spacing.xl)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: String(localized: "common.continue"), systemImage: "arrow.right", isEnabled: viewModel.level != nil, action: onContinue)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(.regularMaterial)
        }
    }
}

struct OnboardingReviewModesScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                OnboardingHeading(
                    stepLabel: String(format: String(localized: "onboarding.step"), 7),
                    title: String(localized: "onboarding.modes.title"),
                    subtitle: String(localized: "onboarding.modes.subtitle")
                )
                VStack(spacing: Spacing.md) {
                    ForEach(ReviewPracticeMode.allCases.filter { viewModel.audioAvailable || $0 != .listening }) { mode in
                        ReviewModeCard(
                            mode: mode,
                            isSelected: viewModel.reviewModes.contains(mode),
                            action: { viewModel.toggleReviewMode(mode) }
                        )
                    }
                }
            }
            .padding(Spacing.xl)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: String(localized: "common.continue"), systemImage: "arrow.right", isEnabled: !viewModel.reviewModes.isEmpty, action: onContinue)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(.regularMaterial)
        }
    }
}

struct OnboardingNotificationsScreen: View {
    let onContinue: () -> Void
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 58))
                .foregroundStyle(Color.lavender)
                .accessibilityHidden(true)
            OnboardingHeading(
                stepLabel: String(format: String(localized: "onboarding.step"), 8),
                title: String(localized: "onboarding.notifications.title"),
                subtitle: String(localized: "onboarding.notifications.subtitle")
            )
            Spacer()
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: String(localized: "onboarding.notifications.enable"), systemImage: "bell.fill", isEnabled: !isRequesting) {
                    enableReminders()
                }
                Button("common.not_now") { declineReminders() }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .disabled(isRequesting)
            }
        }
        .padding(Spacing.xl)
    }

    private func enableReminders() {
        isRequesting = true
        UserDefaults.standard.set(true, forKey: AppSettingsKeys.notificationsEnabled)
        Task {
            await NotificationService.shared.requestPermission()
            await MainActor.run { onContinue() }
        }
    }

    private func declineReminders() {
        UserDefaults.standard.set(false, forKey: AppSettingsKeys.notificationsEnabled)
        onContinue()
    }
}

struct OnboardingCompletionScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(Color.answerKnow)
                .accessibilityHidden(true)
            OnboardingHeading(
                stepLabel: String(localized: "onboarding.complete.eyebrow"),
                title: String(localized: "onboarding.complete.title"),
                subtitle: String(localized: "onboarding.complete.subtitle")
            )
            Spacer()
            PrimaryButton(title: String(localized: "common.start_learning"), systemImage: "arrow.right", action: onContinue)
        }
        .padding(Spacing.xl)
    }
}

struct OnboardingHeading: View {
    var stepLabel: String? = nil
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let stepLabel {
                Text(stepLabel)
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.lavender)
            }
            Text(title)
                .font(.appTitle)
                .foregroundStyle(Color.deepPurple)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OnboardingChoice: Identifiable {
    let id: String
    let title: String
    let systemImage: String
}

struct OnboardingChoiceRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.lavender)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.lavender : Color.lavenderSoft, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.lavender : Color.secondary.opacity(0.35))
                    .font(.title3)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? String(localized: "accessibility.selected") : String(localized: "accessibility.not_selected"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct OnboardingSentenceText: View {
    let sentence: String
    let word: String
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        if let range = sentence.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) {
            let before = Text(sentence[..<range.lowerBound])
            let target = Text(sentence[range])
                .bold()
                .foregroundStyle(Color.deepPurple)
                .underline()
            let after = Text(sentence[range.upperBound...])
            Button {
                onTap()
            } label: {
                (before + target + after)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(isHighlighted ? Color.lavenderSoft.opacity(0.75) : Color.lavenderSoft.opacity(0.35), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: String(localized: "accessibility.sentence_with_word"), word))
            .accessibilityHint(String(localized: "accessibility.learn_word_hint"))
        } else {
            Text(sentence)
                .font(.title2.weight(.medium))
        }
    }
}

struct OnboardingVocabularyCard: View {
    let content: OnboardingDemoContent
    let showsSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.word)
                    .font(.largeWord)
                    .foregroundStyle(Color.deepPurple)
                Spacer()
                if SpeechService.shared.isAvailable(languageCode: content.learningLanguageCode) {
                    SpeakButton(text: content.word, languageCode: content.learningLanguageCode)
                }
            }
            if let transcription = content.transcription {
                Text(transcription)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let translation = content.translation {
                OnboardingDetailRow(title: "Translation", value: translation)
            }
            if let partOfSpeech = content.partOfSpeech {
                OnboardingDetailRow(title: "Part of speech", value: partOfSpeech)
            }
            if let definition = content.definition {
                OnboardingDetailRow(title: "Definition", value: definition)
            }
            OnboardingDetailRow(title: "In context", value: content.sentence)
            if let memoryTip = content.memoryTip {
                OnboardingDetailRow(title: "Memory tip", value: memoryTip)
            }
            if showsSaved {
                Label("onboarding.discovery.added", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.answerKnow)
            }
        }
        .padding(Spacing.lg)
        .background(Color.lavenderSoft.opacity(0.35), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

private struct OnboardingDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
