import Foundation
import SwiftData

/// Powers the "import from a book" flow: take a pasted or scanned passage,
/// surface candidate words, then batch-create cards (auto-translating each).
@Observable
@MainActor
final class ImportWordsViewModel {
    var sourceText = "" {
        didSet { recomputeCandidates() }
    }
    var bookTitle = ""

    private(set) var candidates: [String] = []
    var selected: Set<String> = []

    private(set) var isRecognizing = false
    private(set) var isImporting = false
    /// 0...1 while translating + saving the selected words.
    private(set) var importProgress: Double = 0
    private(set) var importedCount = 0

    private var existingWords: Set<String> = []

    var canImport: Bool { !selected.isEmpty && !isImporting }

    func toggle(_ word: String) {
        if selected.contains(word) {
            selected.remove(word)
        } else {
            selected.insert(word)
        }
        Haptics.tap()
    }

    func selectAll() {
        selected = Set(candidates)
        Haptics.tap()
    }

    func clearSelection() {
        selected.removeAll()
        Haptics.tap()
    }

    /// Loads existing words so already-known vocabulary is filtered out.
    func loadExisting(context: ModelContext) {
        let words = (try? context.fetch(FetchDescriptor<VocabularyWord>())) ?? []
        let languageCode = AppLanguageSettings.learningLanguageCode
        existingWords = Set(
            words.filter { $0.languageCode == languageCode }.map { $0.word.lowercased() }
        )
        recomputeCandidates()
    }

    /// Runs OCR over a picked photo and appends the recognized text.
    func recognizeText(in imageData: Data) async {
        isRecognizing = true
        defer { isRecognizing = false }

        guard let text = try? await TextRecognitionService.recognizeText(in: imageData),
              !text.isEmpty else {
            Haptics.warning()
            return
        }

        sourceText = sourceText.isEmpty ? text : sourceText + "\n" + text
        Haptics.success()
    }

    /// Translates and saves the selected words, scheduling their first review.
    func importSelected(context: ModelContext) async {
        let words = candidates.filter { selected.contains($0) }
        guard !words.isEmpty else { return }

        isImporting = true
        importProgress = 0
        importedCount = 0
        defer { isImporting = false }

        let book = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        for (index, word) in words.enumerated() {
            let translation = (try? await TranslationService.shared.translate(word)) ?? ""

            let newWord = VocabularyWord(
                word: word,
                translation: translation,
                languageCode: AppLanguageSettings.learningLanguageCode,
                bookTitle: book.isEmpty ? nil : book,
                difficulty: .medium,
                nextReviewDate: ReviewScheduler.firstReviewDate(for: .medium)
            )
            context.insert(newWord)
            NotificationService.shared.scheduleReviewNotification(for: newWord)

            importedCount += 1
            importProgress = Double(index + 1) / Double(words.count)
        }

        try? context.save()
        WidgetSync.update(context: context)
        Haptics.success()
    }

    private func recomputeCandidates() {
        candidates = WordExtractor.candidates(
            from: sourceText,
            excluding: existingWords,
            languageCode: AppLanguageSettings.learningLanguageCode
        )
        // Drop selections that are no longer candidates.
        selected = selected.intersection(candidates)
    }
}
