import Testing
import Foundation
@testable import Lucius

@MainActor
struct ImportWordsViewModelTests {
    @Test func extractsCandidatesFromSourceText() {
        let viewModel = ImportWordsViewModel()
        viewModel.sourceText = "serendipity flourish serendipity quick"

        #expect(viewModel.candidates.contains("serendipity"))
        #expect(viewModel.candidates.filter { $0 == "serendipity" }.count == 1)
    }

    @Test func toggleSelectsAndDeselects() {
        let viewModel = ImportWordsViewModel()
        viewModel.sourceText = "magnificent cathedral"

        viewModel.toggle("magnificent")
        #expect(viewModel.selected.contains("magnificent"))

        viewModel.toggle("magnificent")
        #expect(!viewModel.selected.contains("magnificent"))
    }

    @Test func selectAllThenClear() {
        let viewModel = ImportWordsViewModel()
        viewModel.sourceText = "magnificent cathedral wander"

        viewModel.selectAll()
        #expect(viewModel.selected.count == viewModel.candidates.count)

        viewModel.clearSelection()
        #expect(viewModel.selected.isEmpty)
    }

    @Test func changingTextDropsStaleSelection() {
        let viewModel = ImportWordsViewModel()
        viewModel.sourceText = "serendipity flourish"
        viewModel.toggle("serendipity")
        #expect(viewModel.selected.contains("serendipity"))

        viewModel.sourceText = "completely different passage"
        #expect(!viewModel.selected.contains("serendipity"))
    }

    @Test func canImportRequiresSelection() {
        let viewModel = ImportWordsViewModel()
        viewModel.sourceText = "magnificent cathedral"
        #expect(viewModel.canImport == false)

        viewModel.toggle("magnificent")
        #expect(viewModel.canImport == true)
    }
}
