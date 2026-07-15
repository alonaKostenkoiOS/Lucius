import Testing
@testable import Lucius

@MainActor
struct AddWordViewModelTests {
    @Test func scannedTextPopulatesWordAndNormalizesWhitespace() {
        let viewModel = AddWordViewModel()

        viewModel.applyScannedText("  piece\n  of   cake  ")

        #expect(viewModel.word == "piece of cake")
    }

    @Test func recognizedLinePositionsIndividualCameraWords() {
        let matches = ScannedWordExtractor.matches(in: "A well-known word, necessary word!")

        #expect(matches.map(\.word) == ["a", "well-known", "word", "necessary", "word"])
        #expect(matches.map(\.range.location) == [0, 2, 13, 19, 29])
    }

    @Test func scannedContextPopulatesExampleAndNormalizesWhitespace() {
        let viewModel = AddWordViewModel()

        viewModel.applyScannedContext("  She opened\n the old   wooden door. ")

        #expect(viewModel.example == "She opened the old wooden door.")
    }

    @Test func scannedContextReturnsCompleteSentencesAcrossLines() {
        let text = "Before this, another thing happened.\nShe opened the old\nwooden door. Then she ran."

        let sentences = ScannedContextExtractor.sentences(in: text)

        #expect(sentences == [
            "Before this, another thing happened.",
            "She opened the old wooden door.",
            "Then she ran.",
        ])
    }

    @Test func scannedContextFindsSentenceContainingWord() {
        let text = "The hallway was silent.\nShe opened the old wooden door.\nThen she ran."

        let sentence = ScannedContextExtractor.sentence(containing: "wooden", in: text)

        #expect(sentence == "She opened the old wooden door.")
    }

    @Test func contextSearchMatchesOnlyTheWholeWord() {
        #expect(ScannedContextExtractor.contains(searchTerm: "run", in: "They run home."))
        #expect(!ScannedContextExtractor.contains(searchTerm: "run", in: "She was running."))
    }
}
