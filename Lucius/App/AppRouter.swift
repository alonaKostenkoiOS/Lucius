import Foundation
import SwiftUI

/// Drives top-level navigation so external entry points (widget deep links,
/// Siri shortcuts) can steer the UI — e.g. jumping straight to Review.
@Observable
@MainActor
final class AppRouter {
    enum Tab: Hashable {
        case home, review, match, insights, settings
    }

    var selectedTab: Tab = .home
    var pendingReviewWordID: UUID?
    private(set) var reviewRequestID = UUID()
    private(set) var pendingAddWord = false

    /// Routes an incoming deep link (e.g. `lucius://review`) to a tab.
    func handle(_ url: URL) {
        switch url.host {
        case "review":
            pendingAddWord = false
            reviewRequestID = UUID()
            pendingReviewWordID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "word" || $0.name == "wordID" })?
                .value
                .flatMap(UUID.init(uuidString:))
            selectedTab = .review
        case "add":
            clearPendingReview()
            pendingAddWord = true
            selectedTab = .home
        case "match":
            clearPendingReview()
            selectedTab = .match
        case "insights":
            clearPendingReview()
            selectedTab = .insights
        case "home":
            clearPendingReview()
            selectedTab = .home
        case "settings":
            clearPendingReview()
            selectedTab = .settings
        default: break
        }
    }

    private func clearPendingReview() {
        pendingReviewWordID = nil
        reviewRequestID = UUID()
    }

    func consumeAddWordRequest() -> Bool {
        guard pendingAddWord else { return false }
        pendingAddWord = false
        return true
    }
}
