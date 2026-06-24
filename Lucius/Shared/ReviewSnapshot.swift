import Foundation

/// Constants shared between the app and the widget extension.
enum LuciusShared {
    /// App Group used to share the review snapshot with the widget.
    static let appGroup = "group.com.lucius.app"
    static let snapshotKey = "reviewSnapshot"
    /// Deep link the widget opens to jump straight into a review session.
    static let reviewURL = URL(string: "lucius://review")!
}

/// A small, Codable summary of review state that the app writes and the
/// widget reads. Crucially it carries the scheduled review dates, so the
/// widget can recompute "due" over time without the app being launched.
struct ReviewSnapshot: Codable {
    var reviewDates: [Date]
    var streak: Int
    var totalWords: Int
    var masteredCount: Int

    static let empty = ReviewSnapshot(reviewDates: [], streak: 0, totalWords: 0, masteredCount: 0)

    /// How many words are due at the given moment.
    func dueCount(asOf date: Date) -> Int {
        reviewDates.count { $0 <= date }
    }

    /// Upcoming review moments after `date`, sorted — used to schedule
    /// widget timeline entries so the count refreshes exactly when words come due.
    func upcomingDates(after date: Date) -> [Date] {
        reviewDates.filter { $0 > date }.sorted()
    }
}

/// Reads and writes the snapshot in the shared App Group container.
enum SharedStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: LuciusShared.appGroup)
    }

    static func save(_ snapshot: ReviewSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: LuciusShared.snapshotKey)
    }

    static func load() -> ReviewSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: LuciusShared.snapshotKey),
              let snapshot = try? JSONDecoder().decode(ReviewSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
