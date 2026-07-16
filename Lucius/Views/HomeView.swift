import SwiftUI
import SwiftData

/// Main screen: stats, the add-word call to action and recent words.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var isAddingWord = false
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var learningLanguageCode = "en"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    statsRow

                    if viewModel.totalWordsCount > 0 {
                        MasteryRing(
                            fraction: viewModel.masteryFraction,
                            masteredCount: viewModel.masteredCount,
                            totalCount: viewModel.totalWordsCount
                        )

                        ActivityHeatmap(activity: viewModel.activity, streak: viewModel.streak)
                    }

                    PrimaryButton(title: "Add word", systemImage: "plus") {
                        isAddingWord = true
                    }

                    recentWordsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(AppBackgroundGradient())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: VocabularyWord.self) { word in
                WordDetailView(word: word)
            }
            .sheet(isPresented: $isAddingWord, onDismiss: refresh) {
                AddWordView()
            }
            .onAppear(perform: refresh)
        }
        .tint(.lavender)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lucius")
                    .font(.appTitle)
                    .foregroundStyle(Color.deepPurple)

                Text("Remember words. Create scenes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(
                    "Learning \(AppLanguageSettings.displayName(for: learningLanguageCode))",
                    systemImage: "globe"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(Color.lavender)
                .padding(.top, 10)
        }
        .padding(.top, 12)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCardView(
                value: viewModel.totalWordsCount,
                label: "Total words",
                systemImage: "book.closed"
            )
            StatCardView(
                value: viewModel.dueTodayCount,
                label: "Due today",
                systemImage: "clock",
                tint: .orange
            )
            StatCardView(
                value: viewModel.masteredCount,
                label: "Mastered",
                systemImage: "checkmark.seal",
                tint: .green
            )
        }
    }

    @ViewBuilder
    private var recentWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent words")
                .font(.title3.bold())

            if viewModel.recentWords.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: "No words yet",
                    message: "Add the first word from a book you are reading — it becomes a little scene for your memory."
                )
            } else {
                ForEach(viewModel.recentWords) { word in
                    NavigationLink(value: word) {
                        WordCardView(word: word)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refresh() {
        viewModel.refresh(context: modelContext)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
