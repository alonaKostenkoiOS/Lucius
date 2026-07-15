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
}
