import Foundation

/// Constants shared between the app and the widget extension.
enum LuciusShared {
    /// App Group used to share the review snapshot with the widget.
    static let appGroup = "group.com.lucius.app"
    static let snapshotKey = "reviewSnapshot"
    /// Deep link the widget opens to jump straight into a review session.
    static let reviewURL = URL(string: "lucius://review")!
    static let homeURL = URL(string: "lucius://home")!
    static let addWordURL = URL(string: "lucius://add")!

    static func reviewURL(for wordID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "lucius"
        components.host = "review"
        components.queryItems = [URLQueryItem(name: "word", value: wordID.uuidString)]
        return components.url ?? reviewURL
    }
}

/// A small, Codable summary of review state that the app writes and the
/// widget reads. Crucially it carries the scheduled review dates, so the
/// widget can recompute "due" over time without the app being launched.
struct ReviewSnapshot: Codable, Equatable {
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

/// The only vocabulary data persisted for the Smart Word Widget. The app
/// selects the word; the extension only decodes and renders this cache.
struct WidgetWordSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let word: String
    let shortTranslation: String
    let reviewPriority: WidgetReviewPriority
    let lastUpdated: Date
}

enum WidgetReviewPriority: Int, Codable, CaseIterable {
    case overdue
    case difficult
    case learning
    case recent
    case mastered
}

/// Versioned envelope makes schema changes and corrupt data safe to reject.
struct SmartWordWidgetPayload: Codable, Equatable {
    let version: Int
    let selectedWord: WidgetWordSnapshot?
    let selectionDay: Date

    static let currentVersion = 1
    static let empty = SmartWordWidgetPayload(
        version: currentVersion,
        selectedWord: nil,
        selectionDay: .distantPast
    )
}

/// Pure selection rules used by the app snapshot writer and its tests.
/// The selected item is stable for a local calendar day: the only fallback
/// that uses a day-dependent choice is the final mastered-word branch.
enum SmartWordSelection {
    static func select(
        from words: [WidgetWordSnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WidgetWordSnapshot? {
        var unique: [WidgetWordSnapshot] = []
        var seen = Set<UUID>()
        for word in words where seen.insert(word.id).inserted {
            unique.append(word)
        }

        for priority in WidgetReviewPriority.allCases where priority != .mastered {
            let matches = unique.filter { $0.reviewPriority == priority }
            if let selected = matches.sorted(by: priorityOrder).first { return selected }
        }

        let mastered = unique.filter { $0.reviewPriority == .mastered }
        guard !mastered.isEmpty else { return nil }
        let daySeed = calendar.ordinality(of: .day, in: .era, for: calendar.startOfDay(for: now)) ?? 0
        return mastered.min { stableScore($0.id, seed: daySeed) < stableScore($1.id, seed: daySeed) }
    }

    private static func priorityOrder(_ lhs: WidgetWordSnapshot, _ rhs: WidgetWordSnapshot) -> Bool {
        if lhs.lastUpdated != rhs.lastUpdated {
            return lhs.reviewPriority == .recent
                ? lhs.lastUpdated > rhs.lastUpdated
                : lhs.lastUpdated < rhs.lastUpdated
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func stableScore(_ id: UUID, seed: Int) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(abs(seed))) { partial, byte in
            partial &* 31 &+ UInt64(byte)
        }
    }
}

/// Produces the next persisted payload while keeping an unchanged word stable
/// for the current local day. A reviewed or deleted selection is replaced.
enum SmartWordPayloadResolver {
    static func update(
        previous: SmartWordWidgetPayload,
        candidates: [WidgetWordSnapshot],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SmartWordWidgetPayload {
        let today = calendar.startOfDay(for: now)
        let currentPrevious = previous.selectedWord.flatMap { selected in
            candidates.first { $0.id == selected.id }
        }
        let canPreserve = calendar.isDate(previous.selectionDay, inSameDayAs: today)
            && currentPrevious?.lastUpdated == previous.selectedWord?.lastUpdated

        let selected: WidgetWordSnapshot?
        if canPreserve {
            selected = currentPrevious
        } else {
            let alternatives = candidates.filter { $0.id != previous.selectedWord?.id }
            selected = SmartWordSelection.select(
                from: alternatives.isEmpty ? candidates : alternatives,
                now: now,
                calendar: calendar
            )
        }
        return SmartWordWidgetPayload(
            version: SmartWordWidgetPayload.currentVersion,
            selectedWord: selected,
            selectionDay: today
        )
    }
}

enum SmartWordTimeline {
    static func entryDates(from date: Date, calendar: Calendar = .current) -> [Date] {
        [date, nextDayStart(after: date, calendar: calendar)]
    }

    static func nextDayStart(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date.addingTimeInterval(86_400)
    }
}

/// Reads and writes the snapshot in the shared App Group container.
enum SharedStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: LuciusShared.appGroup)
    }

    private static let smartWordKey = "smartWordSnapshot"
    private static let smartWordFilename = "smart-word-widget.json"

    private static var smartWordURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: LuciusShared.appGroup)?
            .appendingPathComponent(smartWordFilename, isDirectory: false)
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

    @discardableResult
    static func saveSmartWord(_ payload: SmartWordWidgetPayload) -> Bool {
        guard let url = smartWordURL,
              let data = try? JSONEncoder().encode(payload)
        else { return false }

        do {
            // Atomic replacement prevents WidgetKit from observing a partial
            // payload when it reloads in a separate process immediately after.
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    static func loadSmartWord() -> SmartWordWidgetPayload {
        if let url = smartWordURL,
           let data = try? Data(contentsOf: url) {
            return decodeSmartWord(data)
        }

        // One-time compatibility path for snapshots written by older builds.
        let legacyData = defaults?.data(forKey: smartWordKey)
        let legacyPayload = decodeSmartWord(legacyData)
        if legacyPayload != .empty {
            _ = saveSmartWord(legacyPayload)
        }
        return legacyPayload
    }

    static func decodeSmartWord(_ data: Data?) -> SmartWordWidgetPayload {
        guard let data,
              let payload = try? JSONDecoder().decode(SmartWordWidgetPayload.self, from: data),
              payload.version == SmartWordWidgetPayload.currentVersion
        else { return .empty }
        return payload
    }
}
