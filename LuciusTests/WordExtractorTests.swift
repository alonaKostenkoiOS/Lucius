import Testing
@testable import Lucius

struct WordExtractorTests {
    @Test func dropsStopwordsAndShortWords() {
        let candidates = WordExtractor.candidates(from: "The quick brown fox over the lazy dog")
        // "the", "over" are stopwords; "fox", "dog" are < 4 letters.
        #expect(candidates == ["quick", "brown", "lazy"])
    }

    @Test func deduplicatesKeepingFirstSeenOrder() {
        let candidates = WordExtractor.candidates(from: "flourish wander flourish wander")
        #expect(candidates == ["flourish", "wander"])
    }

    @Test func stripsSurroundingPunctuation() {
        let candidates = WordExtractor.candidates(from: "\"Serendipity,\" she whispered — quietly.")
        #expect(candidates.contains("serendipity"))
        #expect(candidates.contains("whispered"))
        #expect(candidates.contains("quietly"))
        // No leftover punctuation should sneak in.
        #expect(candidates.allSatisfy { $0.allSatisfy { $0.isLetter || $0 == "'" } })
    }

    @Test func excludesKnownWords() {
        let candidates = WordExtractor.candidates(
            from: "serendipity flourish wander",
            excluding: ["flourish"]
        )
        #expect(!candidates.contains("flourish"))
        #expect(candidates.contains("serendipity"))
    }

    @Test func respectsLimit() {
        // Distinct, purely-alphabetic words (digits would split a token in two).
        func distinctWord(_ index: Int) -> String {
            var n = index
            var letters = ""
            repeat {
                letters.append(Character(UnicodeScalar(97 + n % 26)!))
                n /= 26
            } while n > 0
            return letters + "zzz" // pad to >= 4 letters, keep it unique by prefix
        }

        let passage = (0..<200).map(distinctWord).joined(separator: " ")
        let candidates = WordExtractor.candidates(from: passage, limit: 10)
        #expect(candidates.count == 10)
    }

    @Test func lowercasesOutput() {
        let candidates = WordExtractor.candidates(from: "MAGNIFICENT Cathedral")
        #expect(candidates == ["magnificent", "cathedral"])
    }

    @Test func nonEnglishLanguagesAllowShorterWordsAndSkipEnglishStopwords() {
        let candidates = WordExtractor.candidates(
            from: "la casa es muy bonita",
            languageCode: "es"
        )

        #expect(candidates == ["la", "casa", "es", "muy", "bonita"])
    }
}
