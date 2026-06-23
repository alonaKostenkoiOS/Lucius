import Foundation
import SwiftData

/// Runs scene-image generation app-wide, detached from screen lifecycle:
/// leaving the word screen doesn't cancel the request, and the result
/// is written to storage the moment it arrives.
@Observable
@MainActor
final class SceneImageGenerationManager {
    static let shared = SceneImageGenerationManager()

    private(set) var generatingWordIDs: Set<UUID> = []
    private(set) var failureMessages: [UUID: String] = [:]
    private(set) var etaSeconds: [UUID: Int] = [:]

    private var modelContainer: ModelContainer?

    private init() {}

    /// Called once at app start so results can be saved from anywhere.
    func configure(with container: ModelContainer) {
        modelContainer = container
    }

    func isGenerating(_ word: VocabularyWord) -> Bool {
        generatingWordIDs.contains(word.id)
    }

    func failureMessage(for word: VocabularyWord) -> String? {
        failureMessages[word.id]
    }

    /// Estimated seconds left in the generation queue, when known.
    func eta(for word: VocabularyWord) -> Int? {
        etaSeconds[word.id]
    }

    func clearFailure(for word: VocabularyWord) {
        failureMessages[word.id] = nil
    }

    func generateImage(for word: VocabularyWord) {
        let wordID = word.id
        guard !generatingWordIDs.contains(wordID) else { return }

        let prompt = word.visualAssociation
            ?? "A vivid scene that helps remember the English word \"\(word.word)\" meaning \"\(word.translation)\""

        generatingWordIDs.insert(wordID)
        failureMessages[wordID] = nil

        Task {
            defer {
                generatingWordIDs.remove(wordID)
                etaSeconds[wordID] = nil
            }

            do {
                let imageData = try await ImageGenerationService.shared.generateImage(prompt: prompt) { [weak self] eta in
                    Task { @MainActor in
                        self?.etaSeconds[wordID] = eta
                    }
                }
                saveImage(imageData, forWordID: wordID)
                Haptics.success()
            } catch ImageGenerationService.GenerationError.serviceBusy {
                failureMessages[wordID] = """
                The free image network is busy right now. The volunteer workers couldn't \
                pick up your image in time — try again in a few minutes.
                """
                Haptics.warning()
            } catch ImageGenerationService.GenerationError.offline {
                failureMessages[wordID] = "No internet connection. Reconnect and tap generate again."
                Haptics.warning()
            } catch {
                failureMessages[wordID] = "Something went wrong on the image network. Please try again."
                Haptics.warning()
            }
        }
    }

    /// Re-fetches the word by id — it may have been deleted while generating.
    private func saveImage(_ imageData: Data, forWordID wordID: UUID) {
        guard let context = modelContainer?.mainContext else { return }

        let descriptor = FetchDescriptor<VocabularyWord>(
            predicate: #Predicate { $0.id == wordID }
        )
        guard let word = try? context.fetch(descriptor).first else { return }

        word.sceneImageData = imageData
        word.updatedAt = .now
        try? context.save()
    }
}
