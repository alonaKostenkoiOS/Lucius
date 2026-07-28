import SwiftUI
import WidgetKit

struct SmartWordEntry: TimelineEntry {
    let date: Date
    let word: SharedVocabularyWord?
    let copy: SmartWordCopy
}

struct SmartWordProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmartWordEntry {
        SmartWordEntry(
            date: .now,
            word: SharedVocabularyWord(
                id: UUID(), word: "serendipity", translation: "a happy unexpected discovery",
                languageCode: "en", reviewStatus: "learning", difficulty: "medium",
                nextReviewDate: .now, createdAt: .now, updatedAt: .now,
                mistakeCount: 0, successfulReviewCount: 0, category: nil
            ),
            copy: .english
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SmartWordEntry) -> Void) {
        completion(entry(at: .now, from: SharedStore.loadSmartWord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmartWordEntry>) -> Void) {
        let snapshot = SharedStore.loadSmartWord()
        let now = Date.now
        let nextDay = SmartWordTimeline.nextDayStart(after: now)
        completion(Timeline(
            entries: [entry(at: now, from: snapshot), entry(at: nextDay, from: snapshot)],
            policy: .atEnd
        ))
    }

    private func entry(at date: Date, from snapshot: SmartWordSnapshot) -> SmartWordEntry {
        let calendar = Calendar.current
        let selectedWord: SharedVocabularyWord?
        if let selectionDay = snapshot.selectionDay,
           calendar.isDate(selectionDay, inSameDayAs: date),
           let selectedWordID = snapshot.selectedWordID,
           let persistedWord = snapshot.words.first(where: { $0.id == selectedWordID }) {
            selectedWord = persistedWord
        } else {
            selectedWord = SmartWordSelection.select(
                from: snapshot.words,
                now: date,
                calendar: calendar,
                languageCode: snapshot.words.first?.languageCode
            )
        }

        return SmartWordEntry(
            date: date,
            word: selectedWord,
            copy: snapshot.copy
        )
    }
}

struct SmartWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LuciusSmartWordWidget", provider: SmartWordProvider()) { entry in
            SmartWordWidgetView(entry: entry)
                .widgetURL(entry.word.map { LuciusShared.reviewURL(for: $0.id) } ?? LuciusShared.homeURL)
        }
        // WidgetKit's gallery metadata is kept readable even before the app
        // has written its first localized shared snapshot. The on-device
        // widget content itself is localized by `SmartWordCopy`.
        .configurationDisplayName("Smart Word")
        .description("Learn one personalized word each day.")
        .supportedFamilies([.systemSmall])
    }
}

struct SmartWordWidgetView: View {
    let entry: SmartWordEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let word = entry.word {
                Spacer(minLength: 4)
                Text(word.word)
                    .font(.system(.title2, design: .serif).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(word.translation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let category = word.category, !category.isEmpty {
                    Text(category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.lavenderSoft, in: Capsule())
                }

                Spacer(minLength: 2)
                Text(entry.copy.tapToReview)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.lavender)
            } else {
                Spacer(minLength: 4)
                Text(entry.copy.emptyMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.deepPurple.opacity(0.75), Color.widgetBackground]
                    : [Color.lavenderSoft.opacity(0.9), Color.widgetBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(Color.lavender)
            Text(entry.copy.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(Color.lavender)
        }
    }
}

private extension Color {
    static let lavender = Color(red: 0.55, green: 0.45, blue: 0.92)
    static let lavenderSoft = Color(red: 0.91, green: 0.88, blue: 0.99)
    static let deepPurple = Color(red: 0.33, green: 0.25, blue: 0.55)
    static let widgetBackground = Color(.systemBackground)
}

#Preview(as: .systemSmall) {
    SmartWordWidget()
} timeline: {
    SmartWordEntry(date: .now, word: nil, copy: .english)
}
