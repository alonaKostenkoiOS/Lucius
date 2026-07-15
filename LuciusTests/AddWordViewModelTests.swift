import Testing
@testable import Lucius

@MainActor
struct AddWordViewModelTests {
    @Test func scannedTextPopulatesWordAndNormalizesWhitespace() {
        let viewModel = AddWordViewModel()

        viewModel.applyScannedText("  piece\n  of   cake  ")

        #expect(viewModel.word == "piece of cake")
    }

    @Test func recognizedLineOffersIndividualWords() {
        let words = ScannedWordExtractor.words(in: "A well-known word, necessary word!")

        #expect(words == ["a", "well-known", "word", "necessary"])
    }
}
