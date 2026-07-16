import Foundation

enum ContextReviewMode: String, Codable, CaseIterable, Identifiable {
    case recognize
    case recall
    case use

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recognize: "Recognize"
        case .recall: "Recall"
        case .use: "Use"
        }
    }

    var instruction: String {
        switch self {
        case .recognize: "Choose the word that completes the sentence."
        case .recall: "Type the missing word from memory."
        case .use: "Write your own sentence using this word."
        }
    }
}

struct ContextReviewQuestion: Identifiable {
    let id = UUID()
    let word: VocabularyWord
    let mode: ContextReviewMode
    let originalSentence: String?
    let clozeSentence: String?
    let options: [String]

    var correctAnswer: String { word.word }
    var translation: String? { ContextReviewText.cleaned(word.translation) }
    var memoryTip: String? { ContextReviewText.cleaned(word.visualAssociation) }

    var explanation: String? {
        guard let translation else { return nil }
        return "“\(word.word)” means “\(translation)” in this context."
    }

    static var demo: ContextReviewQuestion {
        let word = VocabularyWord(
            word: "abandon",
            translation: "to leave something behind",
            example: "I decided to abandon my old job.",
            visualAssociation: "Picture yourself putting down an old suitcase and walking forward."
        )
        return ContextReviewQuestion(
            word: word,
            mode: .recognize,
            originalSentence: word.example,
            clozeSentence: "I decided to ____ my old job.",
            options: ["collect", "abandon", "discover", "improve"]
        )
    }
}

struct ContextReviewFeedback {
    let isCorrect: Bool
    let submittedAnswer: String
    let correctAnswer: String
    let originalSentence: String?
    let translation: String?
    let explanation: String?
    let memoryTip: String?
    let responseTime: TimeInterval
}

enum ContextReviewText {
    static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    static func normalizedAnswer(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive], locale: .current)
    }

    static func answersMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizedAnswer(lhs) == normalizedAnswer(rhs)
    }

    static func containsTarget(_ sentence: String, word: String) -> Bool {
        guard let sentence = cleaned(sentence), let word = cleaned(word) else { return false }
        return sentence.range(
            of: word,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        ) != nil
    }

    static func cloze(sentence: String?, word: String) -> String? {
        guard let sentence = cleaned(sentence), let word = cleaned(word),
              let range = sentence.range(
                of: word,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
              )
        else { return nil }
        return sentence.replacingCharacters(in: range, with: "____")
    }
}

enum ContextReviewEngine {
    static func makeQuestion(
        for word: VocabularyWord,
        vocabulary: [VocabularyWord],
        randomizeOptions: Bool = true
    ) -> ContextReviewQuestion {
        // Learner-authored context is especially memorable, so reuse the newest
        // saved sentence in later exercises before falling back to imported text.
        let original = ContextReviewText.cleaned(word.savedUsageSentences.last)
            ?? ContextReviewText.cleaned(word.example)
        let cloze = ContextReviewText.cloze(sentence: original, word: word.word)
        var mode = preferredMode(for: word, hasContext: cloze != nil)
        var options: [String] = []

        if mode == .recognize {
            options = recognitionOptions(
                for: word,
                vocabulary: vocabulary,
                randomize: randomizeOptions
            )
            // Four honest choices are better than invented distractors. Recall remains
            // fully usable for small or newly created vocabularies.
            if options.count != 4 { mode = .recall }
        }

        return ContextReviewQuestion(
            word: word,
            mode: mode,
            originalSentence: original,
            clozeSentence: cloze,
            options: mode == .recognize ? options : []
        )
    }

    static func preferredMode(for word: VocabularyWord, hasContext: Bool) -> ContextReviewMode {
        guard hasContext else { return .use }
        switch word.successfulReviewCount % 4 {
        case 0: return .recognize
        case 1, 3: return .recall
        default: return .use
        }
    }

    static func recognitionOptions(
        for word: VocabularyWord,
        vocabulary: [VocabularyWord],
        randomize: Bool = true
    ) -> [String] {
        let target = ContextReviewText.normalizedAnswer(word.word)
        var seen = Set([target])
        let distractors = vocabulary
            .filter { $0.languageCode == word.languageCode && $0.id != word.id }
            .compactMap { ContextReviewText.cleaned($0.word) }
            .filter {
                let key = ContextReviewText.normalizedAnswer($0)
                return !key.isEmpty && seen.insert(key).inserted
            }
            .sorted {
                abs($0.count - word.word.count) < abs($1.count - word.word.count)
            }
            .prefix(3)

        guard distractors.count == 3 else { return [] }
        let choices = [word.word] + distractors
        return randomize ? choices.shuffled() : choices
    }
}

struct ContextReviewMetrics: Equatable {
    let recognitionAccuracy: Double?
    let recallAccuracy: Double?
    let usageCount: Int
    let mistakeCount: Int
    let averageResponseTime: TimeInterval?

    static func calculate(words: [VocabularyWord], events: [ReviewEvent]) -> Self {
        func accuracy(for mode: ContextReviewMode) -> Double? {
            let matching = events.filter { $0.contextReviewModeRawValue == mode.rawValue }
            guard !matching.isEmpty else { return nil }
            return Double(matching.count(where: \.wasCorrect)) / Double(matching.count)
        }

        let timings = events.compactMap(\.responseTime).filter { $0 >= 0 }
        return ContextReviewMetrics(
            recognitionAccuracy: accuracy(for: .recognize),
            recallAccuracy: accuracy(for: .recall),
            usageCount: words.reduce(0) { $0 + $1.usageCount },
            mistakeCount: words.reduce(0) { $0 + $1.mistakeCount },
            averageResponseTime: timings.isEmpty
                ? nil
                : timings.reduce(0, +) / Double(timings.count)
        )
    }
}
