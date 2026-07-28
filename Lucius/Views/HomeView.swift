import SwiftUI
import SwiftData

/// Main screen: stats, the add-word call to action and recent words.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()
    @State private var dailyFocusViewModel = DailyFocusViewModel()
    @State private var isAddingWord = false
    @State private var isShowingDailyFocus = false
    @State private var isShowingWidgetGuide = false
    @State private var hasDismissedWidgetSuggestion = false
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var learningLanguageCode = "en"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    DailyFocusCard(viewModel: dailyFocusViewModel) {
                        isShowingDailyFocus = true
                    }

                    PrimaryButton(title: String(localized: "home.add_word"), systemImage: "plus") {
                        isAddingWord = true
                    }

                    if shouldShowWidgetSuggestion {
                        AddWidgetEntryCard(
                            preview: widgetPreview,
                            isContextualSuggestion: true,
                            onDismiss: dismissWidgetSuggestion
                        ) {
                            isShowingWidgetGuide = true
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    statsRow

                    if viewModel.totalWordsCount > 0 {
                        MasteryRing(
                            fraction: viewModel.masteryFraction,
                            masteredCount: viewModel.masteredCount,
                            totalCount: viewModel.totalWordsCount
                        )

                        ActivityHeatmap(activity: viewModel.activity, streak: viewModel.streak)
                    }

                    recentWordsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(AppBackgroundGradient())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: VocabularyWord.self) { word in
                WordDetailView(word: word)
            }
            .sheet(isPresented: $isAddingWord, onDismiss: refresh) {
                AddWordView()
            }
            .sheet(isPresented: $isShowingDailyFocus, onDismiss: refresh) {
                if let session = dailyFocusViewModel.session {
                    ReviewView(dailyFocusSession: session)
                }
            }
            .sheet(isPresented: $isShowingWidgetGuide, onDismiss: dismissWidgetSuggestion) {
                WidgetOnboardingView(preview: widgetPreview) {
                    WidgetPromotionStore.dismiss()
                    hasDismissedWidgetSuggestion = true
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                refresh()
                if router.consumeAddWordRequest() { isAddingWord = true }
            }
            .onChange(of: learningLanguageCode) { _, _ in refresh() }
        }
        .tint(.lavender)
    }

    private var shouldShowWidgetSuggestion: Bool {
        !hasDismissedWidgetSuggestion
            && WidgetPromotionStore.shouldSuggest(
                wordCount: viewModel.totalWordsCount,
                onboardingCompleted: OnboardingStore.hasCompleted
            )
    }

    private var widgetPreview: WidgetPreviewContent {
        guard let word = viewModel.recentWords.first else { return .placeholder }
        return WidgetPreviewContent(word: word.word, translation: word.translation)
    }

    private func dismissWidgetSuggestion() {
        guard shouldShowWidgetSuggestion else { return }
        WidgetPromotionStore.dismiss()
        withAnimation(.easeOut) {
            hasDismissedWidgetSuggestion = true
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("home.title")
                    .font(.appTitle)
                    .foregroundStyle(Color.deepPurple)

                Text("home.tagline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(
                    String(format: String(localized: "home.learning"), AppLanguageSettings.displayName(for: learningLanguageCode)),
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
                label: String(localized: "home.total_words"),
                systemImage: "book.closed"
            )
            StatCardView(
                value: viewModel.dueTodayCount,
                label: String(localized: "home.due_today"),
                systemImage: "clock",
                tint: .orange
            )
            StatCardView(
                value: viewModel.masteredCount,
                label: String(localized: "home.mastered"),
                systemImage: "checkmark.seal",
                tint: .green
            )
        }
    }

    @ViewBuilder
    private var recentWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("home.recent_words")
                .font(.title3.bold())

            if viewModel.recentWords.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: String(localized: "home.no_words.title"),
                    message: String(localized: "home.no_words.subtitle")
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
        dailyFocusViewModel.refresh(context: modelContext)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self, DailyFocusSession.self], inMemory: true)
}
