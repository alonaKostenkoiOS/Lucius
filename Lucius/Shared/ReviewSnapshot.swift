import Foundation

/// Constants shared between the app and the widget extension.
enum LuciusShared {
    /// App Group used to share the review snapshot with the widget.
    static let appGroup = "group.com.lucius.app"
    static let snapshotKey = "reviewSnapshot"
    /// Deep link the widget opens to jump straight into a review session.
    static let reviewURL = URL(string: "lucius://review")!
    static let homeURL = URL(string: "lucius://home")!

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

/// The small, Codable representation shared with WidgetKit. Keeping this
/// independent from SwiftData lets the extension start instantly and avoids
/// opening the app's model container in a separate process.
struct SharedVocabularyWord: Codable, Equatable, Identifiable {
    let id: UUID
    let word: String
    let translation: String
    let languageCode: String
    let reviewStatus: String
    let difficulty: String
    let nextReviewDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let mistakeCount: Int
    let successfulReviewCount: Int
    let category: String?
}

struct SmartWordCopy: Codable, Equatable {
    let title: String
    let tapToReview: String
    let emptyMessage: String

    static let english = SmartWordCopy(
        title: "Today's Word",
        tapToReview: "Tap to review",
        emptyMessage: "Add your first words to start learning."
    )
}

struct SmartWordSnapshot: Codable, Equatable {
    var words: [SharedVocabularyWord]
    var updatedAt: Date
    var interfaceLanguageCode: String
    var copy: SmartWordCopy
    var selectedWordID: UUID?
    var selectionDay: Date?

    init(
        words: [SharedVocabularyWord],
        updatedAt: Date,
        interfaceLanguageCode: String,
        copy: SmartWordCopy = .english,
        selectedWordID: UUID? = nil,
        selectionDay: Date? = nil
    ) {
        self.words = words
        self.updatedAt = updatedAt
        self.interfaceLanguageCode = interfaceLanguageCode
        self.copy = copy
        self.selectedWordID = selectedWordID
        self.selectionDay = selectionDay
    }

    private enum CodingKeys: String, CodingKey {
        case words, updatedAt, interfaceLanguageCode, copy, selectedWordID, selectionDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        words = try container.decodeIfPresent([SharedVocabularyWord].self, forKey: .words) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        interfaceLanguageCode = try container.decodeIfPresent(String.self, forKey: .interfaceLanguageCode) ?? "en"
        copy = try container.decodeIfPresent(SmartWordCopy.self, forKey: .copy) ?? .english
        selectedWordID = try container.decodeIfPresent(UUID.self, forKey: .selectedWordID)
        selectionDay = try container.decodeIfPresent(Date.self, forKey: .selectionDay)
    }

    static let empty = SmartWordSnapshot(
        words: [],
        updatedAt: .distantPast,
        interfaceLanguageCode: "en",
        copy: .english,
        selectedWordID: nil,
        selectionDay: nil
    )
}

/// Pure selection rules used by both the app tests and the widget provider.
/// The selected item is stable for a local calendar day: the only fallback
/// that uses a day-dependent choice is the final mastered-word branch.
enum SmartWordSelection {
    static func select(
        from words: [SharedVocabularyWord],
        now: Date = .now,
        calendar: Calendar = .current,
        languageCode: String? = nil
    ) -> SharedVocabularyWord? {
        let languageWords = words.filter { languageCode == nil || $0.languageCode == languageCode }

        var unique: [SharedVocabularyWord] = []
        var seen = Set<UUID>()
        for word in languageWords where seen.insert(word.id).inserted {
            unique.append(word)
        }

        let overdue = unique.filter { $0.nextReviewDate.map { $0 <= now } ?? false }
        let difficult = unique.filter {
            $0.difficulty == "hard" || $0.mistakeCount > 0
        }
        let learning = unique.filter { $0.reviewStatus == "learning" }
        let recent = unique.filter {
            $0.successfulReviewCount == 0 && $0.reviewStatus != "mastered"
        }

        func first(
            from candidates: [SharedVocabularyWord],
            sortedBy areInOrder: (SharedVocabularyWord, SharedVocabularyWord) -> Bool
        ) -> SharedVocabularyWord? {
            candidates.sorted(by: areInOrder).first
        }

        if let word = first(from: overdue, sortedBy: priorityDateOrder) { return word }
        if let word = first(from: difficult, sortedBy: difficultyOrder) { return word }
        if let word = first(from: learning, sortedBy: learningOrder) { return word }
        if let word = first(from: recent, sortedBy: recentOrder) { return word }

        let mastered = unique.filter { $0.reviewStatus == "mastered" }
        guard !mastered.isEmpty else { return nil }
        let daySeed = calendar.ordinality(of: .day, in: .era, for: calendar.startOfDay(for: now)) ?? 0
        let index = abs(daySeed) % mastered.count
        return mastered.sorted { stableScore($0.id, seed: daySeed) < stableScore($1.id, seed: daySeed) }[index]
    }

    private static func priorityDateOrder(_ lhs: SharedVocabularyWord, _ rhs: SharedVocabularyWord) -> Bool {
        let lhsDate = lhs.nextReviewDate ?? .distantPast
        let rhsDate = rhs.nextReviewDate ?? .distantPast
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func difficultyOrder(_ lhs: SharedVocabularyWord, _ rhs: SharedVocabularyWord) -> Bool {
        if lhs.mistakeCount != rhs.mistakeCount { return lhs.mistakeCount > rhs.mistakeCount }
        if lhs.difficulty != rhs.difficulty { return lhs.difficulty == "hard" }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func learningOrder(_ lhs: SharedVocabularyWord, _ rhs: SharedVocabularyWord) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func recentOrder(_ lhs: SharedVocabularyWord, _ rhs: SharedVocabularyWord) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func stableScore(_ id: UUID, seed: Int) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(abs(seed))) { partial, byte in
            partial &* 31 &+ UInt64(byte)
        }
    }
}

/// Resolves the displayed word and produces new persisted state without any
/// dependency on SwiftData or WidgetKit. This keeps refresh behavior testable
/// and identical in the app and extension.
enum SmartWordSnapshotResolver {
    static func displayedWord(
        in snapshot: SmartWordSnapshot,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> SharedVocabularyWord? {
        if let selectionDay = snapshot.selectionDay,
           calendar.isDate(selectionDay, inSameDayAs: date),
           let selectedWordID = snapshot.selectedWordID,
           let selected = snapshot.words.first(where: { $0.id == selectedWordID }) {
            return selected
        }

        return SmartWordSelection.select(
            from: snapshot.words,
            now: date,
            calendar: calendar,
            languageCode: snapshot.words.first?.languageCode
        )
    }

    static func updating(
        previous: SmartWordSnapshot,
        words: [SharedVocabularyWord],
        interfaceLanguageCode: String,
        copy: SmartWordCopy,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SmartWordSnapshot {
        let today = calendar.startOfDay(for: now)
        let previousWord = previous.selectedWordID.flatMap { id in
            previous.words.first { $0.id == id }
        }
        let currentPreviousWord = previous.selectedWordID.flatMap { id in
            words.first { $0.id == id }
        }
        let sameDay = previous.selectionDay.map {
            calendar.isDate($0, inSameDayAs: today)
        } ?? false
        let selectionWasReviewed = previousWord.map { oldWord in
            guard let currentPreviousWord else { return true }
            return oldWord.reviewStatus != currentPreviousWord.reviewStatus
                || oldWord.nextReviewDate != currentPreviousWord.nextReviewDate
                || oldWord.mistakeCount != currentPreviousWord.mistakeCount
                || oldWord.successfulReviewCount != currentPreviousWord.successfulReviewCount
        } ?? true

        let selected: SharedVocabularyWord?
        if sameDay, let currentPreviousWord, !selectionWasReviewed {
            selected = currentPreviousWord
        } else {
            let eligible = selectionWasReviewed
                ? words.filter { $0.id != previous.selectedWordID }
                : words
            selected = SmartWordSelection.select(
                from: eligible.isEmpty ? words : eligible,
                now: now,
                calendar: calendar,
                languageCode: words.first?.languageCode
            )
        }

        let stateChanged = previous.words != words
            || previous.selectedWordID != selected?.id
            || !sameDay
            || previous.copy != copy
            || previous.interfaceLanguageCode != interfaceLanguageCode

        return SmartWordSnapshot(
            words: words,
            updatedAt: stateChanged ? now : previous.updatedAt,
            interfaceLanguageCode: interfaceLanguageCode,
            copy: copy,
            selectedWordID: selected?.id,
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

    static func saveSmartWord(_ snapshot: SmartWordSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: smartWordKey)
    }

    static func loadSmartWord() -> SmartWordSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: smartWordKey),
              let snapshot = try? JSONDecoder().decode(SmartWordSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
