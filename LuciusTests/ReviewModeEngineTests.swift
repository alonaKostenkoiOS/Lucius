import Testing
@testable import Lucius

struct ReviewModeEngineTests {
    @Test func mixedExpandsToEveryAvailableExercise() {
        let withAudio = ReviewModeEngine.expandedSelection([.mixed], audioAvailable: true)
        let withoutAudio = ReviewModeEngine.expandedSelection([.mixed], audioAvailable: false)

        #expect(Set(withAudio) == Set(ReviewPracticeMode.exerciseModes))
        #expect(!withoutAudio.contains(.listening))
        #expect(withoutAudio.count == ReviewPracticeMode.exerciseModes.count - 1)
    }

    @Test func multipleSelectionsRemainLimitedToChosenModes() {
        let modes = ReviewModeEngine.expandedSelection(
            [.cloze, .typeWord, .useSentence],
            audioAvailable: true
        )

        #expect(Set(modes) == [.cloze, .typeWord, .useSentence])
    }

    @Test func translationChoicesContainOneCorrectAndThreeDistinctDistractors() {
        let target = VocabularyWord(word: "abandon", translation: "leave")
        let vocabulary = [
            target,
            VocabularyWord(word: "collect", translation: "gather"),
            VocabularyWord(word: "improve", translation: "enhance"),
            VocabularyWord(word: "discover", translation: "find"),
            VocabularyWord(word: "repeat", translation: "leave")
        ]

        let options = ReviewModeEngine.translationOptions(
            for: target,
            vocabulary: vocabulary,
            randomize: false
        )

        #expect(options.first == "leave")
        #expect(Set(options) == ["leave", "gather", "enhance", "find"])
        #expect(Set(options).count == 4)
    }

    @Test func modeCompatibilityUsesOnlyDataTheWordCanSupport() {
        let target = VocabularyWord(word: "abandon", translation: "leave")
        let modes = ReviewModeEngine.compatibleModes(
            for: target,
            vocabulary: [target],
            selection: [.cloze, .multipleChoice, .typeWord, .listening, .useSentence],
            audioAvailable: true
        )

        #expect(Set(modes) == [.typeWord, .useSentence])
    }

    @Test func unavailableSelectedModeFallsBackToFlashcards() {
        let word = VocabularyWord(word: "abandon", translation: "leave")
        let mode = ReviewModeEngine.chooseMode(
            for: word,
            vocabulary: [word],
            selection: [.cloze],
            audioAvailable: false
        )

        #expect(mode == .flashcards)
    }
}
