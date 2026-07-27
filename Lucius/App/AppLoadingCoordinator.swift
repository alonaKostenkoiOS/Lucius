import Foundation
import Observation

/// Owns the one loading state used by the application root.
/// Work that completes within the threshold never presents a loading overlay.
@Observable
@MainActor
final class AppLoadingCoordinator {
    private(set) var isShowing = true

    private var isPreparing = true
    private var generation = 0
    private let presentationThreshold: Duration = .milliseconds(300)

    func beginPreparation() {
        generation += 1
        let currentGeneration = generation
        isPreparing = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: presentationThreshold)
            guard generation == currentGeneration, isPreparing else { return }
            isShowing = true
        }
    }

    func finishPreparation() async {
        await Task.yield()
        isPreparing = false
        generation += 1
        guard isShowing else { return }
        isShowing = false
    }
}
