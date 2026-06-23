import Foundation

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
        limit: Int = 60
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        // Split on anything that isn't a letter or an inner apostrophe.
        let tokens = text.lowercased().split { !$0.isLetter && $0 != "'" }

        for token in tokens {
            let word = token.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            guard word.count >= 4,
                  !stopwords.contains(word),
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
