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
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.circular)
                    .tint(.lavender)
                    .scaleEffect(1.15)
                    .accessibilityLabel(String(localized: "daily_focus.progress"))
                    .accessibilityValue(String(format: String(localized: "daily_focus.progress_value"), viewModel.completedCount, viewModel.wordCount))
            }

            if viewModel.isCompleted {
                Text("daily_focus.completed_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("daily_focus.come_back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lavender)
            } else if viewModel.wordCount > 0 {
                HStack {
                    Text(String(format: String(localized: "daily_focus.about_minutes"), viewModel.estimatedMinutes))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.deepPurple)
                    Spacer()
                    PrimaryButton(
                        title: String(localized: viewModel.isInProgress ? "daily_focus.continue" : "daily_focus.start"),
                        systemImage: viewModel.isInProgress ? "arrow.right" : "play.fill",
                        action: onStart
                    )
                    .fixedSize(horizontal: true, vertical: false)
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
}

#Preview("Daily Focus") {
    DailyFocusCard(viewModel: DailyFocusViewModel()) {}
        .padding()
        .background(AppBackgroundGradient())
}
