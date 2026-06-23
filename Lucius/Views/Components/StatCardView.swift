import SwiftUI

/// A small stat tile for the home screen (e.g. "12 / Total words").
struct StatCardView: View {
    let value: Int
    let label: String
    let systemImage: String
    var tint: Color = .lavender

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .padding(8)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md + 2)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(value: 24, label: "Total words", systemImage: "book.closed")
        StatCardView(value: 5, label: "Due today", systemImage: "clock", tint: .orange)
        StatCardView(value: 8, label: "Mastered", systemImage: "checkmark.seal", tint: .green)
    }
    .padding()
    .background(Color.appBackground)
}
