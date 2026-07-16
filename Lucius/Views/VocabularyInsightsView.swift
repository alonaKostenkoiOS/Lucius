import Charts
import SwiftData
import SwiftUI

struct VocabularyInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettingsKeys.learningLanguageCode) private var languageCode = "en"
    @State private var viewModel = VocabularyInsightsViewModel()

    var body: some View {
        NavigationStack {
            VocabularyInsightsContent(snapshot: viewModel.snapshot)
                .navigationTitle("Insights")
                .onAppear(perform: refresh)
                .onChange(of: languageCode) {
                    refresh()
                }
        }
        .tint(.lavender)
    }

    private func refresh() {
        viewModel.refresh(context: modelContext, languageCode: languageCode)
    }
}

struct VocabularyInsightsContent: View {
    let snapshot: VocabularyAnalyticsSnapshot
    @State private var selectedRange: InsightsTimeRange = .daily

    private let grid = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                overviewSection
                progressSection

                if let cefr = snapshot.cefrDistribution {
                    cefrSection(cefr)
                }

                if !snapshot.hardestPartsOfSpeech.isEmpty || !snapshot.mostForgottenWords.isEmpty {
                    weakAreasSection
                }

                learningSpeedSection
                if snapshot.overview.total > 0 || snapshot.totalReviews > 0 {
                    insightSection
                }
            }
            .padding(Spacing.xl)
        }
        .background(AppBackgroundGradient())
    }

    private var overviewSection: some View {
        InsightsSection(title: "Vocabulary overview", systemImage: "books.vertical") {
            HStack(spacing: Spacing.lg) {
                InsightProgressRing(
                    fraction: snapshot.overview.total == 0
                        ? 0
                        : Double(snapshot.overview.learned) / Double(snapshot.overview.total),
                    centerValue: "\(snapshot.overview.learned)",
                    caption: "learned"
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("\(snapshot.overview.total) words")
                        .font(.title2.bold())
                        .foregroundStyle(Color.deepPurple)
                    Text("\(Int(snapshot.reviewAccuracy * 100))% recall accuracy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: grid, spacing: Spacing.md) {
                InsightMetricCard(value: snapshot.overview.total, label: "Total", icon: "book.closed", tint: .lavender)
                InsightMetricCard(value: snapshot.overview.new, label: "New", icon: "sparkles", tint: .blue)
                InsightMetricCard(value: snapshot.overview.forgotten, label: "Forgotten", icon: "arrow.uturn.backward", tint: .red)
                InsightMetricCard(value: snapshot.overview.dueToday, label: "Due today", icon: "clock", tint: .orange)
            }
        }
    }

    private var progressSection: some View {
        InsightsSection(title: "Learning progress", systemImage: "chart.xyaxis.line") {
            Picker("Time range", selection: $selectedRange) {
                ForEach(InsightsTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            let points = snapshot.chartPoints[selectedRange] ?? []
            Chart(points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: chartUnit),
                    y: .value("Reviews", point.reviews)
                )
                .foregroundStyle(Color.lavender.opacity(0.35))
                .cornerRadius(3)

                LineMark(
                    x: .value("Date", point.date, unit: chartUnit),
                    y: .value("Words learned", point.learned)
                )
                .foregroundStyle(Color.deepPurple)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date, unit: chartUnit),
                    y: .value("Words learned", point.learned)
                )
                .foregroundStyle(Color.deepPurple)
            }
            .frame(height: 190)
            .chartYAxis { AxisMarks(position: .leading) }
            .chartLegend(.hidden)

            HStack(spacing: Spacing.lg) {
                InsightLegend(color: .deepPurple, label: "Words learned")
                InsightLegend(color: .lavender.opacity(0.45), label: "Reviews")
                Spacer()
            }

            HStack(spacing: Spacing.md) {
                InsightMetricCard(value: snapshot.totalReviews, label: "Reviews", icon: "checkmark.circle", tint: .lavender)
                InsightMetricCard(value: snapshot.streak, label: "Day streak", icon: "flame.fill", tint: .orange)
            }
        }
    }

    private var chartUnit: Calendar.Component {
        switch selectedRange {
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        }
    }

    private func cefrSection(_ values: [VocabularyAnalyticsSnapshot.CEFRStat]) -> some View {
        InsightsSection(title: "CEFR distribution", systemImage: "chart.bar.fill") {
            ForEach(values) { item in
                VStack(spacing: Spacing.xs) {
                    HStack {
                        Text(item.level.rawValue)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.deepPurple)
                            .frame(width: 30, alignment: .leading)
                        Text("\(item.count) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.weight(.semibold))
                    }

                    ProgressView(value: item.percentage)
                        .tint(cefrColor(item.level))
                }
            }
        }
    }

    private func cefrColor(_ level: CEFRLevel) -> Color {
        switch level {
        case .a1: .green
        case .a2: .mint
        case .b1: .blue
        case .b2: .lavender
        case .c1: .purple
        case .c2: .deepPurple
        }
    }

    private var weakAreasSection: some View {
        InsightsSection(title: "Weak areas", systemImage: "scope") {
            if let hardest = snapshot.hardestPartsOfSpeech.first {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "textformat.abc")
                        .foregroundStyle(Color.orange)
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hardest part of speech")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hardest.name)
                            .font(.headline)
                    }
                    Spacer()
                    Text("\(hardest.mistakeCount) mistakes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if !snapshot.mostForgottenWords.isEmpty {
                Divider()
                Text("Most forgotten words")
                    .font(.subheadline.weight(.semibold))

                ForEach(snapshot.mostForgottenWords) { word in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.word)
                                .font(.body.weight(.semibold))
                            Text(word.translation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label("\(word.mistakeCount)", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var learningSpeedSection: some View {
        InsightsSection(title: "Learning speed", systemImage: "gauge.with.dots.needle.67percent") {
            LazyVGrid(columns: grid, spacing: Spacing.md) {
                if let days = snapshot.averageMemorizationDays {
                    InsightValueCard(
                        value: days.formatted(.number.precision(.fractionLength(1))),
                        unit: "days to memorize",
                        tint: .blue
                    )
                }
                if let reviews = snapshot.averageSuccessfulReviewsToMastery {
                    InsightValueCard(
                        value: reviews.formatted(.number.precision(.fractionLength(1))),
                        unit: "reviews to mastery",
                        tint: .purple
                    )
                }
                InsightValueCard(
                    value: snapshot.dailyLearningPace.formatted(.number.precision(.fractionLength(1))),
                    unit: "new words / day",
                    tint: .green
                )
            }
        }
    }

    private var insightSection: some View {
        VStack(spacing: Spacing.md) {
            InsightCallout(
                icon: "brain.head.profile",
                text: "You remember \(Int(snapshot.reviewAccuracy * 100))% of reviewed words.",
                tint: .lavender
            )

            if let weakest = snapshot.hardestPartsOfSpeech.first {
                InsightCallout(
                    icon: "scope",
                    text: "\(weakest.name) are your weakest category right now.",
                    tint: .orange
                )
            }

            InsightCallout(
                icon: "bolt.fill",
                text: "You learn about \(snapshot.dailyLearningPace.formatted(.number.precision(.fractionLength(1)))) new words per day.",
                tint: .green
            )
        }
    }
}

// MARK: - Reusable analytics components

struct InsightsSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .foregroundStyle(Color.deepPurple)
            content
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct InsightMetricCard: View {
    let value: Int
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(value, format: .number)
                    .font(.headline.bold())
                    .foregroundStyle(Color.deepPurple)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct InsightValueCard: View {
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(Spacing.md)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

struct InsightProgressRing: View {
    let fraction: Double
    let centerValue: String
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.lavenderSoft, lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(
                    AngularGradient(colors: [.lavender, .deepPurple], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(centerValue).font(.headline.bold())
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 92, height: 92)
        .accessibilityElement(children: .combine)
    }
}

private struct InsightLegend: View {
    let color: Color
    let label: String

    var body: some View {
        Label {
            Text(label).font(.caption).foregroundStyle(.secondary)
        } icon: {
            Circle().fill(color).frame(width: 8, height: 8)
        }
    }
}

struct InsightCallout: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())
            Text(text)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.lg)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .elevation(.card)
    }
}

#Preview("Vocabulary Insights — Demo") {
    NavigationStack {
        VocabularyInsightsContent(snapshot: .demo())
            .navigationTitle("Insights")
    }
    .preferredColorScheme(.light)
}
