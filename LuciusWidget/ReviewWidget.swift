import WidgetKit
import SwiftUI

// The widget runs in its own process and doesn't link the app module, so it
// keeps a tiny local copy of the brand colors rather than sharing Theme.swift.
private extension Color {
    static let lavender = Color(red: 0.55, green: 0.45, blue: 0.92)
    static let lavenderSoft = Color(red: 0.91, green: 0.88, blue: 0.99)
    static let deepPurple = Color(red: 0.33, green: 0.25, blue: 0.55)
}

struct ReviewEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let streak: Int
    let totalWords: Int
}

struct ReviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(date: .now, dueCount: 3, streak: 5, totalWords: 42)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> Void) {
        completion(entry(at: .now, from: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewEntry>) -> Void) {
        let snapshot = SharedStore.load()
        let now = Date.now

        // One entry now, plus an entry at each upcoming due moment so the
        // count ticks up exactly when words come due — no app launch needed.
        var entries = [entry(at: now, from: snapshot)]
        for dueDate in snapshot.upcomingDates(after: now).prefix(24) {
            entries.append(entry(at: dueDate, from: snapshot))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, from snapshot: ReviewSnapshot) -> ReviewEntry {
        ReviewEntry(
            date: date,
            dueCount: snapshot.dueCount(asOf: date),
            streak: snapshot.streak,
            totalWords: snapshot.totalWords
        )
    }
}

struct ReviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LuciusReviewWidget", provider: ReviewProvider()) { entry in
            ReviewWidgetView(entry: entry)
                .widgetURL(LuciusShared.reviewURL)
        }
        .configurationDisplayName("Words to review")
        .description("See how many words are due and jump straight into a review.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct ReviewWidgetView: View {
    var entry: ReviewEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                Spacer()
                if entry.streak > 0 { streakBadge }
            }
            .foregroundStyle(Color.lavender)
            .font(.caption)

            Spacer()

            Text("\(entry.dueCount)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.deepPurple)
            Text(dueLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { background }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lucius")
                    .font(.system(.headline, design: .serif).weight(.bold))
                    .foregroundStyle(Color.deepPurple)
                Spacer()
                Text("\(entry.dueCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.deepPurple)
                Text(dueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                if entry.streak > 0 { streakBadge }
                Spacer()
                Text(entry.dueCount > 0 ? "Review now →" : "All caught up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(entry.dueCount > 0 ? Color.lavender : Color.lavender.opacity(0.4), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { background }
    }

    // MARK: - Lock Screen

    private var circular: some View {
        Gauge(value: Double(min(entry.dueCount, 20)), in: 0...20) {
            Image(systemName: "rectangle.stack.fill")
        } currentValueLabel: {
            Text("\(entry.dueCount)")
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Lucius", systemImage: "rectangle.stack.fill")
                .font(.caption.weight(.semibold))
            Text("\(entry.dueCount) \(dueLabel)")
                .font(.headline)
            if entry.streak > 0 {
                Text("🔥 \(entry.streak)-day streak")
                    .font(.caption2)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Pieces

    private var streakBadge: some View {
        Text("🔥 \(entry.streak)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.deepPurple)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.lavenderSoft, in: Capsule())
    }

    private var dueLabel: String {
        entry.dueCount == 1 ? "word due" : "words due"
    }

    private var background: some View {
        LinearGradient(colors: [.lavenderSoft, .white], startPoint: .top, endPoint: .bottom)
    }
}

#Preview(as: .systemSmall) {
    ReviewWidget()
} timeline: {
    ReviewEntry(date: .now, dueCount: 3, streak: 5, totalWords: 42)
    ReviewEntry(date: .now, dueCount: 0, streak: 5, totalWords: 42)
}
