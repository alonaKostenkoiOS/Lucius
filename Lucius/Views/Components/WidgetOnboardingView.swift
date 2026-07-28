import SwiftUI

enum WidgetPromotionStore {
    static let dismissedKey = "smartWordWidgetPromotionDismissed"
    static let minimumWordCount = 3

    static func shouldSuggest(
        wordCount: Int,
        onboardingCompleted: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        wordCount >= minimumWordCount
            && onboardingCompleted
            && !defaults.bool(forKey: dismissedKey)
    }

    static func dismiss(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: dismissedKey)
    }
}

struct WidgetPreviewContent {
    let word: String
    let translation: String

    static let placeholder = WidgetPreviewContent(
        word: String(localized: "widget_onboarding.preview_word"),
        translation: String(localized: "widget_onboarding.preview_translation")
    )
}

struct AddWidgetEntryCard: View {
    let preview: WidgetPreviewContent
    var isContextualSuggestion = false
    var onDismiss: (() -> Void)?
    let onAddWidget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.lg) {
                SmartWordWidgetPreview(content: preview, compact: true)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .top) {
                        Text(isContextualSuggestion
                             ? "widget_onboarding.suggestion.title"
                             : "widget_onboarding.card.title")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if let onDismiss {
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("widget_onboarding.dismiss")
                        }
                    }

                    Text(isContextualSuggestion
                         ? "widget_onboarding.suggestion.description"
                         : "widget_onboarding.card.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PrimaryButton(
                title: String(localized: "widget_onboarding.add_widget"),
                systemImage: "rectangle.badge.plus",
                action: onAddWidget
            )
        }
        .padding(Spacing.lg)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}

struct WidgetOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let preview: WidgetPreviewContent
    let onComplete: () -> Void

    @State private var showsHelp = false
    @State private var previewIsFloating = false

    private let steps: [(icon: String, key: LocalizedStringKey)] = [
        ("hand.tap.fill", "widget_onboarding.step.1"),
        ("plus.square.fill", "widget_onboarding.step.2"),
        ("magnifyingglass", "widget_onboarding.step.3"),
        ("rectangle.inset.filled", "widget_onboarding.step.4"),
        ("checkmark.circle.fill", "widget_onboarding.step.5"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    hero

                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("widget_onboarding.instructions.title")
                            .font(.sectionTitle)

                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            instructionRow(number: index + 1, icon: step.icon, text: step.key)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    help

                    PrimaryButton(title: String(localized: "widget_onboarding.got_it")) {
                        onComplete()
                        dismiss()
                    }
                }
                .padding(Spacing.xl)
            }
            .background(AppBackgroundGradient())
            .navigationTitle("widget_onboarding.navigation_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .tint(.lavender)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                previewIsFloating = true
            }
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.lg) {
            ZStack(alignment: .bottomTrailing) {
                SmartWordWidgetPreview(content: preview)
                    .frame(width: 158, height: 158)
                    .offset(y: previewIsFloating ? -4 : 0)

                Image("WelcomePoster")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.cardBackground, lineWidth: 3))
                    .accessibilityHidden(true)
            }

            VStack(spacing: Spacing.sm) {
                Text("widget_onboarding.sheet.title")
                    .font(.title2.bold())
                    .foregroundStyle(Color.deepPurple)
                    .multilineTextAlignment(.center)

                Text("widget_onboarding.sheet.description")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func instructionRow(
        number: Int,
        icon: String,
        text: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(Color.lavenderSoft)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.deepPurple)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String(format: String(localized: "widget_onboarding.step_number"), number))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lavender)
                Text(text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut) {
                    showsHelp.toggle()
                }
            } label: {
                HStack {
                    Label("widget_onboarding.help.action", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: showsHelp ? "chevron.up" : "chevron.down")
                }
                .font(.headline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.deepPurple)

            if showsHelp {
                Text("widget_onboarding.help.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.lg)
        .cardStyle()
    }
}

struct SmartWordWidgetPreview: View {
    let content: WidgetPreviewContent
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : Spacing.sm) {
            HStack(spacing: 5) {
                Image(systemName: "book.closed.fill")
                Text("smart_word.title")
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.lavender)

            Spacer(minLength: 0)

            Text(content.word)
                .font(compact ? .system(.headline, design: .serif).bold() : .cardWord)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(content.translation)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text("smart_word.tap_to_review")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .lineLimit(1)
        }
        .padding(compact ? Spacing.md : Spacing.lg)
        .background {
            LinearGradient(
                colors: [Color.lavenderSoft.opacity(0.85), Color.cardBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? Radius.lg : Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? Radius.lg : Radius.xl, style: .continuous)
                .stroke(Color.primary.opacity(0.06))
        }
        .elevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: String(localized: "widget_onboarding.preview_accessibility"),
                content.word,
                content.translation
            )
        )
    }
}
