import Foundation
import NaturalLanguage

enum InsightsTimeRange: String, CaseIterable, Identifiable, Hashable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

enum CEFRLevel: String, CaseIterable, Codable, Identifiable, Hashable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    var id: String { rawValue }
}

struct VocabularyAnalyticsSnapshot {
    struct Overview {
        let total: Int
        let learned: Int
        let new: Int
        let forgotten: Int
        let dueToday: Int
    }

    struct ChartPoint: Identifiable {
        let date: Date
        let learned: Int
        let reviews: Int
        var id: Date { date }
    }

    struct CEFRStat: Identifiable {
        let level: CEFRLevel
        let count: Int
        let percentage: Double
        var id: CEFRLevel { level }
    }

    struct WeakPartOfSpeech: Identifiable {
        let name: String
        let mistakeCount: Int
        var id: String { name }
    }

    struct WeakWord: Identifiable {
        let id: UUID
        let word: String
        let translation: String
        let mistakeCount: Int
    }

    let overview: Overview
    let chartPoints: [InsightsTimeRange: [ChartPoint]]
    let streak: Int
    let reviewAccuracy: Double
    let cefrDistribution: [CEFRStat]?
    let hardestPartsOfSpeech: [WeakPartOfSpeech]
    let mostForgottenWords: [WeakWord]
    let averageMemorizationDays: Double?
    let averageSuccessfulReviewsToMastery: Double?
    let dailyLearningPace: Double
    let totalReviews: Int

    static let empty = VocabularyAnalyticsSnapshot(
        overview: Overview(total: 0, learned: 0, new: 0, forgotten: 0, dueToday: 0),
        chartPoints: [:],
        streak: 0,
        reviewAccuracy: 0,
        cefrDistribution: nil,
        hardestPartsOfSpeech: [],
        mostForgottenWords: [],
        averageMemorizationDays: nil,
        averageSuccessfulReviewsToMastery: nil,
        dailyLearningPace: 0,
        totalReviews: 0
    )

    static func demo(now: Date = .now, calendar: Calendar = .current) -> VocabularyAnalyticsSnapshot {
        let points = (0..<7).compactMap { offset -> ChartPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: now) else { return nil }
            return ChartPoint(date: date, learned: [4, 7, 5, 9, 6, 11, 8][offset], reviews: [9, 12, 8, 16, 13, 19, 15][offset])
        }
        let cefrCounts = [18, 24, 20, 15, 8, 3]
        let cefrTotal = cefrCounts.reduce(0, +)

        return VocabularyAnalyticsSnapshot(
            overview: Overview(total: 88, learned: 64, new: 16, forgotten: 8, dueToday: 12),
            chartPoints: [.daily: points, .weekly: points, .monthly: points],
            streak: 12,
            reviewAccuracy: 0.82,
            cefrDistribution: zip(CEFRLevel.allCases, cefrCounts).map {
                CEFRStat(level: $0.0, count: $0.1, percentage: Double($0.1) / Double(cefrTotal))
            },
            hardestPartsOfSpeech: [WeakPartOfSpeech(name: "Verbs", mistakeCount: 21)],
            mostForgottenWords: [
                WeakWord(id: UUID(), word: "withstand", translation: "витримувати", mistakeCount: 7),
                WeakWord(id: UUID(), word: "dwindle", translation: "скорочуватися", mistakeCount: 5),
            ],
            averageMemorizationDays: 5.4,
            averageSuccessfulReviewsToMastery: 3.2,
            dailyLearningPace: 14,
            totalReviews: 92
        )
    }
}

enum VocabularyAnalyticsEngine {
    static func makeSnapshot(
        words: [VocabularyWord],
        reviewEvents: [ReviewEvent],
        languageCode: String,
        cefrLookup: [String: CEFRLevel]? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> VocabularyAnalyticsSnapshot {
        let languageWords = words.filter { $0.languageCode == languageCode }
        let languageEvents = reviewEvents.filter {
            $0.languageCode == languageCode || ($0.languageCode == nil && languageCode == "en")
        }
        let learnedWords = languageWords.filter {
            $0.reviewStatus == .familiar || $0.reviewStatus == .mastered
        }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let overview = VocabularyAnalyticsSnapshot.Overview(
            total: languageWords.count,
            learned: learnedWords.count,
            new: languageWords.count { $0.reviewStatus == .new },
            forgotten: languageWords.count { $0.mistakeCount > 0 },
            dueToday: languageWords.count {
                guard let date = $0.nextReviewDate else { return false }
                return date < endOfToday
            }
        )

        let accuracy: Double
        if languageEvents.isEmpty {
            accuracy = languageWords.isEmpty ? 0 : Double(learnedWords.count) / Double(languageWords.count)
        } else {
            accuracy = Double(languageEvents.count(where: \.wasCorrect)) / Double(languageEvents.count)
        }

        let masteredWithTiming = languageWords.filter {
            $0.reviewStatus == .mastered && $0.firstMasteredAt != nil
        }
        let averageDays = average(masteredWithTiming.compactMap { word in
            word.firstMasteredAt.map { max(0, $0.timeIntervalSince(word.createdAt) / 86_400) }
        })
        let masteredWithReviews = languageWords.filter {
            $0.reviewStatus == .mastered && $0.successfulReviewCount > 0
        }
        let averageReviews = average(masteredWithReviews.map { Double($0.successfulReviewCount) })

        let paceStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        let recentWords = languageWords.count { $0.createdAt >= paceStart && $0.createdAt <= now }
        let pace = Double(recentWords) / 7

        let weakWords = languageWords
            .filter { $0.mistakeCount > 0 }
            .sorted {
                $0.mistakeCount == $1.mistakeCount
                    ? $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                    : $0.mistakeCount > $1.mistakeCount
            }
            .prefix(5)
            .map {
                VocabularyAnalyticsSnapshot.WeakWord(
                    id: $0.id,
                    word: $0.word,
                    translation: $0.translation,
                    mistakeCount: $0.mistakeCount
                )
            }

        return VocabularyAnalyticsSnapshot(
            overview: overview,
            chartPoints: Dictionary(uniqueKeysWithValues: InsightsTimeRange.allCases.map { range in
                (range, chartPoints(words: learnedWords, events: languageEvents, range: range, now: now, calendar: calendar))
            }),
            streak: learningStreak(events: languageEvents, now: now, calendar: calendar),
            reviewAccuracy: accuracy,
            cefrDistribution: cefrStats(words: languageWords, lookup: cefrLookup),
            hardestPartsOfSpeech: hardestPartsOfSpeech(words: languageWords, languageCode: languageCode),
            mostForgottenWords: Array(weakWords),
            averageMemorizationDays: averageDays,
            averageSuccessfulReviewsToMastery: averageReviews,
            dailyLearningPace: pace,
            totalReviews: languageEvents.count
        )
    }

    private static func chartPoints(
        words: [VocabularyWord],
        events: [ReviewEvent],
        range: InsightsTimeRange,
        now: Date,
        calendar: Calendar
    ) -> [VocabularyAnalyticsSnapshot.ChartPoint] {
        let configuration: (component: Calendar.Component, count: Int) = switch range {
        case .daily: (.day, 7)
        case .weekly: (.weekOfYear, 8)
        case .monthly: (.month, 6)
        }
        let currentBucket = bucketStart(for: now, range: range, calendar: calendar)

        return (0..<configuration.count).reversed().compactMap { offset in
            guard let start = calendar.date(
                byAdding: configuration.component,
                value: -offset,
                to: currentBucket
            ), let end = calendar.date(byAdding: configuration.component, value: 1, to: start)
            else { return nil }

            let learned = words.count { word in
                let date = word.firstMasteredAt ?? word.updatedAt
                return date >= start && date < end
            }
            let reviews = events.count { $0.date >= start && $0.date < end }
            return VocabularyAnalyticsSnapshot.ChartPoint(date: start, learned: learned, reviews: reviews)
        }
    }

    private static func bucketStart(
        for date: Date,
        range: InsightsTimeRange,
        calendar: Calendar
    ) -> Date {
        switch range {
        case .daily:
            return calendar.startOfDay(for: date)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    private static func learningStreak(
        events: [ReviewEvent],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let activeDays = Set(events.map { calendar.startOfDay(for: $0.date) })
        var cursor = calendar.startOfDay(for: now)
        if !activeDays.contains(cursor),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
           activeDays.contains(yesterday) {
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private static func cefrStats(
        words: [VocabularyWord],
        lookup: [String: CEFRLevel]?
    ) -> [VocabularyAnalyticsSnapshot.CEFRStat]? {
        guard let lookup, !lookup.isEmpty else { return nil }
        let levels = words.compactMap { lookup[$0.word.lowercased()] }
        guard !levels.isEmpty else { return nil }

        return CEFRLevel.allCases.map { level in
            let count = levels.count { $0 == level }
            return VocabularyAnalyticsSnapshot.CEFRStat(
                level: level,
                count: count,
                percentage: Double(count) / Double(levels.count)
            )
        }
    }

    private static func hardestPartsOfSpeech(
        words: [VocabularyWord],
        languageCode: String
    ) -> [VocabularyAnalyticsSnapshot.WeakPartOfSpeech] {
        var mistakes: [String: Int] = [:]
        for word in words where word.mistakeCount > 0 {
            guard let part = LocalLinguisticAnalyzer.partOfSpeech(for: word, languageCode: languageCode) else {
                continue
            }
            mistakes[part, default: 0] += word.mistakeCount
        }

        return mistakes
            .map { VocabularyAnalyticsSnapshot.WeakPartOfSpeech(name: $0.key, mistakeCount: $0.value) }
            .sorted { $0.mistakeCount > $1.mistakeCount }
            .prefix(3)
            .map { $0 }
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

enum LocalCEFRDictionary {
    static func load(bundle: Bundle = .main) -> [String: CEFRLevel]? {
        guard let url = bundle.url(forResource: "cefr_words", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }

        let values = raw.reduce(into: [String: CEFRLevel]()) { result, entry in
            if let level = CEFRLevel(rawValue: entry.value.uppercased()) {
                result[entry.key.lowercased()] = level
            }
        }
        return values.isEmpty ? nil : values
    }
}

private enum LocalLinguisticAnalyzer {
    static func partOfSpeech(for word: VocabularyWord, languageCode: String) -> String? {
        let source = word.example ?? word.word
        guard !source.isEmpty else { return nil }
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = source
        tagger.setLanguage(NLLanguage(rawValue: languageCode), range: source.startIndex..<source.endIndex)
        let index = source.range(of: word.word, options: [.caseInsensitive, .diacriticInsensitive])?.lowerBound
            ?? source.startIndex
        guard let tag = tagger.tag(at: index, unit: .word, scheme: .lexicalClass).0 else { return nil }

        switch tag {
        case .verb: return "Verbs"
        case .noun: return "Nouns"
        case .adjective: return "Adjectives"
        case .adverb: return "Adverbs"
        case .pronoun: return "Pronouns"
        default: return nil
        }
    }
}
