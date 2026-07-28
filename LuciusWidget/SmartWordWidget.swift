import SwiftUI
import WidgetKit

struct SmartWordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWordSnapshot?
}

struct SmartWordProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmartWordEntry {
        SmartWordEntry(
            date: .now,
            word: WidgetWordSnapshot(
                id: UUID(),
                word: "serendipity",
                shortTranslation: "a happy unexpected discovery",
                reviewPriority: .learning,
                lastUpdated: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SmartWordEntry) -> Void) {
        completion(entry(at: .now, from: SharedStore.loadSmartWord()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmartWordEntry>) -> Void) {
        let snapshot = SharedStore.loadSmartWord()
        let now = Date.now
        completion(Timeline(
            entries: [entry(at: now, from: snapshot)],
            policy: .after(SmartWordTimeline.nextDayStart(after: now))
        ))
    }

    private func entry(at date: Date, from snapshot: SmartWordWidgetPayload) -> SmartWordEntry {
        return SmartWordEntry(
            date: date,
            word: snapshot.selectedWord
        )
    }
}

struct SmartWordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LuciusSmartWordWidget", provider: SmartWordProvider()) { entry in
            SmartWordWidgetView(entry: entry)
                .widgetURL(entry.word.map { LuciusShared.reviewURL(for: $0.id) } ?? LuciusShared.addWordURL)
        }
        .configurationDisplayName(widgetLocalized("smart_word.display_name"))
        .description(widgetLocalized("smart_word.description"))
        .supportedFamilies([.systemSmall])
    }
}

struct SmartWordWidgetView: View {
    let entry: SmartWordEntry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let word = entry.word {
                content(word)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.widgetBackground, Color.deepPurple.opacity(0.32)]
                    : [Color.lavenderSoft, Color.widgetBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityElement(children: .combine)
    }

    private func content(_ word: WidgetWordSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            Text(word.word)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.62)

            Text(word.shortTranslation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 2)

            Text(verbatim: widgetLocalized("smart_word.review_action"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .lineLimit(1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 4)
            Text(verbatim: widgetLocalized("smart_word.empty_title"))
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(verbatim: widgetLocalized("smart_word.open_action"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "book.closed.fill")
                .accessibilityHidden(true)
            Text(verbatim: widgetLocalized("smart_word.title"))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.caption2.weight(.bold))
        .tracking(0.6)
        .foregroundStyle(Color.lavender)
    }
}

/// Widget views are hosted by a system process. Resolve against the extension
/// bundle explicitly so the host application's localization bundle is never
/// used and an unresolved key is never presented as user-facing copy.
private func widgetLocalized(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
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
    SmartWordEntry(date: .now, word: nil)
}
