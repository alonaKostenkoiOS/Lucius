import Foundation

enum ReviewPracticeMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case flashcards
    case cloze
    case multipleChoice
    case typeWord
    case listening
    case useSentence
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flashcards: "Flashcards"
        case .cloze: "Cloze"
        case .multipleChoice: "Multiple Choice"
        case .typeWord: "Type the Word"
        case .listening: "Listening"
        case .useSentence: "Use in a Sentence"
        case .mixed: "Mixed"
        }
    }

    var description: String {
        switch self {
        case .flashcards: "Review words one by one."
        case .cloze: "Fill in the missing word using context."
        case .multipleChoice: "Choose the correct translation."
        case .typeWord: "Recall the word from its meaning."
        case .listening: "Recognize spoken vocabulary."
        case .useSentence: "Practice active recall in your own context."
        case .mixed: "Randomly combine all available review types."
        }
    }

    var systemImage: String {
        switch self {
        case .flashcards: "rectangle.stack"
        case .cloze: "text.badge.checkmark"
        case .multipleChoice: "scope"
        case .typeWord: "keyboard"
        case .listening: "headphones"
        case .useSentence: "text.bubble"
        case .mixed: "dice"
        }
    }

    static var exerciseModes: [ReviewPracticeMode] {
        allCases.filter { $0 != .mixed }
    }
}

enum ReviewModePreferences {
    private static let key = "selectedReviewPracticeModes"

    static func load(audioAvailable: Bool) -> Set<ReviewPracticeMode> {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        var selection = Set(stored.compactMap(ReviewPracticeMode.init(rawValue:)))
        if !audioAvailable { selection.remove(.listening) }
        if selection.isEmpty { selection = [.mixed] }
        return selection
    }

    static func save(_ selection: Set<ReviewPracticeMode>) {
        UserDefaults.standard.set(selection.map(\.rawValue).sorted(), forKey: key)
    }
}

enum ReviewModeEngine {
    static func expandedSelection(
        _ selection: Set<ReviewPracticeMode>,
        audioAvailable: Bool
    ) -> [ReviewPracticeMode] {
        if selection.contains(.mixed) {
            return ReviewPracticeMode.exerciseModes.filter {
                audioAvailable || $0 != .listening
            }
        }
        return ReviewPracticeMode.exerciseModes.filter {
            selection.contains($0) && (audioAvailable || $0 != .listening)
        }
    }

    static func compatibleModes(
        for word: VocabularyWord,
        vocabulary: [VocabularyWord],
        selection: Set<ReviewPracticeMode>,
        audioAvailable: Bool
    ) -> [ReviewPracticeMode] {
        expandedSelection(selection, audioAvailable: audioAvailable).filter { mode in
            switch mode {
            case .flashcards, .useSentence:
                true
            case .cloze:
                ContextReviewText.cloze(sentence: context(for: word), word: word.word) != nil
            case .multipleChoice:
                translationOptions(for: word, vocabulary: vocabulary).count == 4
            case .typeWord:
                ContextReviewText.cleaned(word.translation) != nil
            case .listening:
                audioAvailable
                    && ContextReviewEngine.recognitionOptions(
                        for: word,
                        vocabulary: vocabulary
                    ).count == 4
            case .mixed:
                false
            }
        }
    }

    static func chooseMode(
        for word: VocabularyWord,
        vocabulary: [VocabularyWord],
        selection: Set<ReviewPracticeMode>,
        audioAvailable: Bool
    ) -> ReviewPracticeMode {
        compatibleModes(
            for: word,
            vocabulary: vocabulary,
            selection: selection,
            audioAvailable: audioAvailable
        ).randomElement() ?? .flashcards
    }

    static func translationOptions(
        for word: VocabularyWord,
        vocabulary: [VocabularyWord],
        randomize: Bool = true
    ) -> [String] {
        guard let correct = ContextReviewText.cleaned(word.translation) else { return [] }
        let target = ContextReviewText.normalizedAnswer(correct)
        var seen = Set([target])
        let distractors = vocabulary
            .filter { $0.languageCode == word.languageCode && $0.id != word.id }
            .compactMap { ContextReviewText.cleaned($0.translation) }
            .filter {
                let key = ContextReviewText.normalizedAnswer($0)
                return !key.isEmpty && seen.insert(key).inserted
            }
            .sorted {
                abs($0.count - correct.count) < abs($1.count - correct.count)
            }
            .prefix(3)

        guard distractors.count == 3 else { return [] }
        let choices = [correct] + distractors
        return randomize ? choices.shuffled() : choices
    }

    static func context(for word: VocabularyWord) -> String? {
        ContextReviewText.cleaned(word.savedUsageSentences.last)
            ?? ContextReviewText.cleaned(word.example)
    }
}
