import Foundation
import NaturalLanguage

/// Turns a passage of English prose into a short list of candidate words
/// worth learning: drops punctuation, common stopwords, very short words
/// and duplicates, keeping first-seen order.
enum WordExtractor {
    /// High-frequency words that are rarely worth a flashcard.
    private static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can", "her", "was", "one",
        "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see",
        "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use", "that",
        "this", "with", "have", "from", "they", "will", "would", "there", "their", "what", "about",
        "which", "when", "your", "said", "them", "then", "were", "been", "into", "more", "some",
        "could", "than", "other", "after", "first", "where", "those", "these", "being", "very",
        "just", "over", "such", "only", "also", "back", "even", "most", "much", "many", "like",
        "down", "here", "well", "still", "should", "because", "between", "through", "before",
        "around", "though", "while", "again", "against", "himself", "herself", "itself",
    ]

    /// Returns up to `limit` candidate words, lowercased, excluding any in `existing`.
    static func candidates(
        from text: String,
        excluding existing: Set<String> = [],
        limit: Int = 60,
        languageCode: String = AppLanguageSettings.learningLanguageCode
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let minimumLength = languageCode == "en" ? 4 : 2
        let languagesWithoutRequiredWordSpacing: Set<String> = ["zh", "ja", "th", "lo", "km", "my"]

        let tokens: [String]
        if languagesWithoutRequiredWordSpacing.contains(languageCode) {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text
            tokenizer.setLanguage(NLLanguage(rawValue: languageCode))
            var localizedTokens: [String] = []
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                localizedTokens.append(String(text[range]).lowercased())
                return true
            }
            tokens = localizedTokens
        } else {
            // Split on anything that isn't a letter or an inner apostrophe.
            tokens = text.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
        }

        for token in tokens {
            let word = token.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            guard word.count >= minimumLength,
                  (languageCode != "en" || !stopwords.contains(word)),
                  !existing.contains(word),
                  !seen.contains(word),
                  word.allSatisfy({ $0.isLetter || $0 == "'" })
            else { continue }

            seen.insert(word)
            result.append(word)
            if result.count >= limit { break }
        }

        return result
    }
}
