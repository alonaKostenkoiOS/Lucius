import UIKit

/// Thin wrapper over UIKit feedback generators so taps, answers and
/// celebrations feel tactile. Centralized here to keep call sites tiny
/// and consistent. All methods are no-ops on devices without a Taptic Engine.
enum Haptics {
    /// A light tap for ordinary button presses and selections.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A firmer tap for committing an action (answer submitted, word saved).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Selection change — used while dragging a review card past a threshold.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
