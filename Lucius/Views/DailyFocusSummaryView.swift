import SwiftUI

struct DailyFocusSummaryView: View {
    let session: DailyFocusSession
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.answerKnow)
                .symbolEffect(.bounce, value: session.isCompleted && !reduceMotion)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text("daily_focus.summary_title")
                    .font(.appTitle)
                    .foregroundStyle(Color.deepPurple)
                    .multilineTextAlignment(.center)
                Text(String(format: String(localized: "daily_focus.summary_reviewed"), session.wordIDs.count))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(String(format: String(localized: "daily_focus.summary_results"), session.correctCount, session.incorrectCount))
                    .font(.headline)
                    .foregroundStyle(Color.deepPurple)
            }
            Spacer()
            PrimaryButton(title: String(localized: "common.done"), systemImage: "checkmark", action: onDone)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
