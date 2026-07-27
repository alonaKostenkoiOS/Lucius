import SwiftUI

struct DailyFocusCard: View {
    let viewModel: DailyFocusViewModel
    let onStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(viewModel.isCompleted
                         ? String(localized: "daily_focus.completed_title")
                         : viewModel.isInProgress
                            ? String(localized: "daily_focus.continue_title")
                            : String(localized: "daily_focus.title"))
                        .font(.title2.bold())
                        .foregroundStyle(Color.deepPurple)
                    if viewModel.wordCount > 0 {
                        Text(detailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Spacing.sm)
                DailyFocusProgressIndicator(progress: viewModel.progress)
                    .accessibilityLabel(String(localized: "daily_focus.progress"))
                    .accessibilityValue(String(format: String(localized: "daily_focus.progress_value"), viewModel.completedCount, viewModel.wordCount))
            }

            if viewModel.isCompleted {
                Text("daily_focus.completed_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if viewModel.wordCount > 0 {
                // Keep the compact layout when it fits, but move the CTA below
                // the estimate on narrow screens or with larger Dynamic Type.
                // This prevents long localized titles (for example, Ukrainian)
                // from being compressed or clipped by the surrounding HStack.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Spacing.md) {
                        durationLabel
                        Spacer(minLength: Spacing.sm)
                        actionButton
                            .frame(minWidth: 150, maxWidth: 210)
                    }

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        durationLabel
                        actionButton
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Text("daily_focus.empty_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.isCompleted)
    }

    private var detailText: String {
        if viewModel.isCompleted {
            return String(format: String(localized: "daily_focus.completed_count"), viewModel.wordCount)
        }
        return String(format: String(localized: "daily_focus.ready_count"), viewModel.wordCount)
    }

    private var durationLabel: some View {
        Text(String(format: String(localized: "daily_focus.about_minutes"), viewModel.estimatedMinutes))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.deepPurple)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actionButton: some View {
        PrimaryButton(
            title: String(localized: viewModel.isInProgress ? "daily_focus.continue" : "daily_focus.start"),
            systemImage: viewModel.isInProgress ? "arrow.right" : "play.fill",
            action: onStart
        )
    }
}

private struct DailyFocusProgressIndicator: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.lavenderSoft, lineWidth: 5)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    Color.lavender,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 34, height: 34)
    }
}

#Preview("Daily Focus") {
    DailyFocusCard(viewModel: DailyFocusViewModel()) {}
        .padding()
        .background(AppBackgroundGradient())
}
