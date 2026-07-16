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

    /// Routes an incoming deep link (e.g. `lucius://review`) to a tab.
    func handle(_ url: URL) {
        switch url.host {
        case "review": selectedTab = .review
        case "match": selectedTab = .match
        case "insights": selectedTab = .insights
        case "home": selectedTab = .home
        case "settings": selectedTab = .settings
        default: break
        }
    }
}
