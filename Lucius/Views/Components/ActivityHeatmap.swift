import SwiftUI

/// A GitHub-style activity grid: one square per day, columns are weeks,
/// darker lavender = more reviews that day. Paired with the current streak.
struct ActivityHeatmap: View {
    let activity: [HomeViewModel.DayActivity]
    let streak: Int

    private let rows = 7 // days per week column
    private let cell: CGFloat = 13
    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("Activity", systemImage: "flame.fill")
                    .font(.cardLabel)
                    .foregroundStyle(Color.lavender)
                    .textCase(.uppercase)
                Spacer()
                if streak > 0 {
                    Text("\(streak)-day streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.deepPurple)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: gridRows, spacing: gap) {
                        ForEach(activity) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: day.count))
                                .frame(width: cell, height: cell)
                                .id(day.id)
                                .accessibilityLabel(accessibilityText(for: day))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    guard let last = activity.last else { return }
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var gridRows: [GridItem] {
        Array(repeating: GridItem(.fixed(cell), spacing: gap), count: rows)
    }

    /// Buckets the day's review count into four lavender intensities.
    private func color(for count: Int) -> Color {
        switch count {
        case 0: Color.lavender.opacity(0.10)
        case 1...2: Color.lavender.opacity(0.35)
        case 3...5: Color.lavender.opacity(0.65)
        default: Color.lavender
        }
    }

    private func accessibilityText(for day: HomeViewModel.DayActivity) -> String {
        let date = day.date.formatted(date: .abbreviated, time: .omitted)
        return day.count == 0 ? "\(date): no reviews" : "\(date): \(day.count) reviews"
    }
}

#Preview {
    let sample = (0..<91).reversed().compactMap { offset -> HomeViewModel.DayActivity? in
        guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now) else { return nil }
        return HomeViewModel.DayActivity(date: date, count: offset % 5)
    }
    return ActivityHeatmap(activity: sample, streak: 4)
        .padding()
        .background(Color.appBackground)
}
