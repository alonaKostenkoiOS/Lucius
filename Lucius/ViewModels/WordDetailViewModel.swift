import Foundation
import SwiftData

/// Review actions, scene image management and deletion
/// for a single word's detail screen.
@Observable
@MainActor
final class WordDetailViewModel {
    let word: VocabularyWord

    /// Briefly true after the image lands in the photo library.
    private(set) var isSavedToPhotos = false

    /// Set when an answer pushed this word to mastered, so the view can celebrate.
    var celebrate = false

    init(word: VocabularyWord) {
        self.word = word
    }

    func answer(_ answer: ReviewAnswer, context: ModelContext) {
        let outcome = ReviewScheduler.apply(answer, to: word)
        context.insert(ReviewEvent(wasCorrect: answer == .knowIt))
        try? context.save()
        NotificationService.shared.scheduleReviewNotification(for: word)

        if outcome.didReachMastered {
            celebrate = true
            Haptics.success()
        }
    }

    /// Stores the image produced by Image Playground (it hands back a temp file URL).
    func saveSceneImage(from url: URL, context: ModelContext) {
        guard let imageData = try? Data(contentsOf: url) else { return }
        word.sceneImageData = imageData
        word.updatedAt = .now
        try? context.save()
    }

    func removeSceneImage(context: ModelContext) {
        Haptics.impact(.rigid)
        word.sceneImageData = nil
        word.updatedAt = .now
        try? context.save()
    }

    func saveSceneImageToPhotos() async {
        guard let imageData = word.sceneImageData,
              await PhotoLibraryService.shared.save(imageData: imageData) else {
            Haptics.warning()
            return
        }

        // Show the "Saved" confirmation for a moment.
        Haptics.success()
        isSavedToPhotos = true
        try? await Task.sleep(for: .seconds(2))
        isSavedToPhotos = false
    }

    func delete(context: ModelContext) {
        NotificationService.shared.cancelNotification(for: word)
        context.delete(word)
        try? context.save()
    }
}
