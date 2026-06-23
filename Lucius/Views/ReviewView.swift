import SwiftUI
import SwiftData

/// Review session: due words shown one at a time as flip-and-swipe cards.
struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ReviewViewModel()
    @State private var isRevealed = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                Group {
                    if let word = viewModel.currentWord {
                        reviewCard(for: word)
                    } else {
                        EmptyStateView(
                            systemImage: "checkmark.circle",
                            title: "All caught up",
                            message: "No words to review right now. Come back when a reminder arrives."
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CelebrationView(isActive: $viewModel.celebrate)
            }
            .navigationTitle("Review")
            .onAppear {
                viewModel.loadDueWords(context: modelContext)
                isRevealed = false
            }
        }
        .tint(.lavender)
    }

    private func reviewCard(for word: VocabularyWord) -> some View {
        VStack(spacing: Spacing.xl) {
            sessionHeader

            Spacer(minLength: 0)

            SwipeReviewCard(word: word, isRevealed: $isRevealed) { submit($0) }
            // Recreate the card per word so flip/drag state resets cleanly.
            .id(word.id)

            Spacer(minLength: 0)

            if isRevealed {
                VStack(spacing: Spacing.sm) {
                    ReviewAnswerButtons { submit($0) }
                    Text("or swipe the card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                PrimaryButton(title: "Show answer", systemImage: "eye") {
                    withAnimation { isRevealed = true }
                }
            }
        }
        .padding(Spacing.xl)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isRevealed)
    }

    private var sessionHeader: some View {
        VStack(spacing: Spacing.sm) {
            Text("\(viewModel.remainingCount) left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(viewModel.remainingCount) words left to review")

            ProgressView(value: viewModel.sessionProgress)
                .tint(.lavender)
                .animation(.easeInOut, value: viewModel.sessionProgress)
        }
    }

    private func submit(_ answer: ReviewAnswer) {
        // Let the swipe/flip settle, then advance to the next word.
        viewModel.answer(answer, context: modelContext)
        withAnimation { isRevealed = false }
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
