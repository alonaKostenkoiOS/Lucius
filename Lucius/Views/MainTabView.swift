import SwiftUI
import SwiftData

/// Root navigation: Home, Review, Match, Insights and Settings tabs.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppRouter.Tab.home)

            ReviewView()
                .tabItem {
                    Label("Review", systemImage: "rectangle.stack")
                }
                .tag(AppRouter.Tab.review)

            WordMatchView()
                .tabItem {
                    Label("Match", systemImage: "arrow.left.arrow.right.circle")
                }
                .tag(AppRouter.Tab.match)

            VocabularyInsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                }
                .tag(AppRouter.Tab.insights)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(.lavender)
        // The palette is built for a light, airy look — keep it
        // consistent even when the device is in dark mode.
        .preferredColorScheme(.light)
    }
}

// MARK: - Word matching

/// A short exercise that connects saved words with shuffled translations.
struct WordMatchView: View {
    @Query(sort: \VocabularyWord.createdAt, order: .reverse) private var words: [VocabularyWord]
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var learningLanguageCode = "en"
    @State private var viewModel = WordMatchViewModel()

    private var languageWords: [VocabularyWord] {
        words.filter { $0.languageCode == learningLanguageCode }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                if viewModel.pairs.count < 2 {
                    EmptyStateView(
                        systemImage: "arrow.left.arrow.right",
                        title: "Add at least two words",
                        message: "Matching becomes available when your vocabulary has two words with translations."
                    )
                    .padding(Spacing.xl)
                } else {
                    gameContent
                }
            }
            .navigationTitle("Match")
            .onAppear {
                viewModel.refreshIfNeeded(from: languageWords)
            }
            .onChange(of: words.map(\.id)) {
                viewModel.refreshIfNeeded(from: languageWords)
            }
            .onChange(of: learningLanguageCode) {
                viewModel.startRound(from: languageWords)
            }
        }
        .tint(.lavender)
    }

    private var gameContent: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Text(viewModel.isComplete ? "Round complete" : "Connect each pair")
                        .font(.title2.bold())
                        .foregroundStyle(Color.deepPurple)

                    Text(viewModel.isComplete
                         ? "You matched every word."
                         : "Choose a word, then choose its translation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ProgressView(value: viewModel.progress)
                        .tint(.lavender)
                }

                if viewModel.isComplete {
                    completionCard
                } else {
                    matchingColumns
                }
            }
            .padding(Spacing.xl)
        }
    }

    private var matchingColumns: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            optionColumn(title: "Words", pairs: viewModel.pairs, isWordColumn: true)
            optionColumn(title: "Translations", pairs: viewModel.translationOptions, isWordColumn: false)
        }
    }

    private func optionColumn(
        title: String,
        pairs: [WordMatchPair],
        isWordColumn: Bool
    ) -> some View {
        VStack(spacing: Spacing.md) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .textCase(.uppercase)

            ForEach(pairs) { pair in
                matchButton(pair: pair, isWord: isWordColumn)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func matchButton(pair: WordMatchPair, isWord: Bool) -> some View {
        let isMatched = viewModel.matchedIDs.contains(pair.id)
        let isSelected = isWord
            ? viewModel.selectedWordID == pair.id
            : viewModel.selectedTranslationID == pair.id
        let isIncorrect = isWord
            ? viewModel.incorrectWordID == pair.id
            : viewModel.incorrectTranslationID == pair.id

        return Button {
            isWord ? viewModel.selectWord(pair.id) : viewModel.selectTranslation(pair.id)
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(isWord ? pair.word : pair.translation)
                    .font(isWord ? .body.weight(.semibold) : .body)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if isMatched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .foregroundStyle(isMatched ? Color.secondary : Color.deepPurple)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .background(buttonBackground(isMatched: isMatched, isSelected: isSelected, isIncorrect: isIncorrect))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(buttonBorder(isSelected: isSelected, isIncorrect: isIncorrect), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isMatched || viewModel.isResolving)
        .opacity(isMatched ? 0.55 : 1)
        .accessibilityLabel(isWord ? "Word: \(pair.word)" : "Translation: \(pair.translation)")
        .accessibilityValue(isMatched ? "Matched" : isSelected ? "Selected" : "Not selected")
    }

    private func buttonBackground(isMatched: Bool, isSelected: Bool, isIncorrect: Bool) -> Color {
        if isIncorrect { return Color.red.opacity(0.12) }
        if isMatched { return Color.green.opacity(0.1) }
        if isSelected { return Color.lavenderSoft }
        return Color.cardBackground
    }

    private func buttonBorder(isSelected: Bool, isIncorrect: Bool) -> Color {
        if isIncorrect { return .red }
        return isSelected ? .lavender : .clear
    }

    private var completionCard: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            PrimaryButton(title: "New round", systemImage: "arrow.clockwise") {
                viewModel.startRound(from: languageWords)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xxl)
        .cardStyle()
    }
}

struct WordMatchPair: Identifiable, Equatable {
    let id: UUID
    let word: String
    let translation: String
}

@Observable
@MainActor
final class WordMatchViewModel {
    static let roundSize = 5

    private(set) var pairs: [WordMatchPair] = []
    private(set) var translationOptions: [WordMatchPair] = []
    private(set) var matchedIDs: Set<UUID> = []
    private(set) var selectedWordID: UUID?
    private(set) var selectedTranslationID: UUID?
    private(set) var incorrectWordID: UUID?
    private(set) var incorrectTranslationID: UUID?
    private(set) var isResolving = false

    private var sourceIDs: Set<UUID> = []

    var progress: Double {
        guard !pairs.isEmpty else { return 0 }
        return Double(matchedIDs.count) / Double(pairs.count)
    }

    var isComplete: Bool {
        !pairs.isEmpty && matchedIDs.count == pairs.count
    }

    func refreshIfNeeded(from words: [VocabularyWord]) {
        let currentIDs = Set(words.map(\.id))
        guard pairs.isEmpty || currentIDs != sourceIDs else { return }
        startRound(from: words)
    }

    func startRound(from words: [VocabularyWord]) {
        sourceIDs = Set(words.map(\.id))
        let eligible = Self.eligiblePairs(from: words)
        pairs = Array(eligible.shuffled().prefix(Self.roundSize))
        translationOptions = pairs.shuffled()
        matchedIDs = []
        clearSelection()
    }

    func selectWord(_ id: UUID) {
        guard !matchedIDs.contains(id), !isResolving else { return }
        selectedWordID = id
        resolveSelectionIfReady()
    }

    func selectTranslation(_ id: UUID) {
        guard !matchedIDs.contains(id), !isResolving else { return }
        selectedTranslationID = id
        resolveSelectionIfReady()
    }

    static func eligiblePairs(from words: [VocabularyWord]) -> [WordMatchPair] {
        var seenWords = Set<String>()
        var seenTranslations = Set<String>()
        var result: [WordMatchPair] = []

        for item in words {
            let word = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
            let translation = item.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            let wordKey = word.lowercased()
            let translationKey = translation.lowercased()

            guard !word.isEmpty,
                  !translation.isEmpty,
                  !seenWords.contains(wordKey),
                  !seenTranslations.contains(translationKey)
            else { continue }

            seenWords.insert(wordKey)
            seenTranslations.insert(translationKey)
            result.append(WordMatchPair(id: item.id, word: word, translation: translation))
        }

        return result
    }

    private func resolveSelectionIfReady() {
        guard let wordID = selectedWordID, let translationID = selectedTranslationID else { return }

        if wordID == translationID {
            matchedIDs.insert(wordID)
            Haptics.success()
            clearSelection()
        } else {
            incorrectWordID = wordID
            incorrectTranslationID = translationID
            isResolving = true
            Haptics.warning()

            Task {
                try? await Task.sleep(for: .milliseconds(550))
                guard incorrectWordID == wordID, incorrectTranslationID == translationID else { return }
                clearSelection()
            }
        }
    }

    private func clearSelection() {
        selectedWordID = nil
        selectedTranslationID = nil
        incorrectWordID = nil
        incorrectTranslationID = nil
        isResolving = false
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter())
        .modelContainer(for: [VocabularyWord.self, ReviewEvent.self], inMemory: true)
}
