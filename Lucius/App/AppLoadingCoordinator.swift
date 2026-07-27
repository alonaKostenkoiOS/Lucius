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
    private var didCompleteInitialPreparation = false
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
        // Let the first artwork frame render before dismissing the coordinator.
        // Without this small minimum, the SwiftUI overlay can disappear before
        // the first window frame and expose a black launch-screen gap.
        if !didCompleteInitialPreparation {
            try? await Task.sleep(for: presentationThreshold)
            didCompleteInitialPreparation = true
        }
        await Task.yield()
        isPreparing = false
        generation += 1
        guard isShowing else { return }
        isShowing = false
    }
}
