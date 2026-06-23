import SwiftUI

/// A progress ring showing how much of the vocabulary has been mastered,
/// with a growing sprout that "blooms" as mastery approaches 100%.
struct MasteryRing: View {
    let fraction: Double
    let masteredCount: Int
    let totalCount: Int

    @State private var animated = false

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ring
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(Int((animated ? fraction : 0) * 100))%")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.deepPurple)
                    .contentTransition(.numericText())
                Text("mastered")
                    .font(.cardLabel)
                    .foregroundStyle(Color.lavender)
                    .textCase(.uppercase)
                Text("\(masteredCount) of \(totalCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { animated = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mastery progress")
        .accessibilityValue("\(Int(fraction * 100)) percent, \(masteredCount) of \(totalCount) words mastered")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.lavenderSoft, lineWidth: 9)

            Circle()
                .trim(from: 0, to: animated ? fraction : 0)
                .stroke(
                    AngularGradient(colors: [.lavender, .deepPurple, .lavender], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: fraction >= 1 ? "leaf.fill" : "leaf")
                .font(.title3)
                .foregroundStyle(Color.answerKnow)
                .scaleEffect(animated ? 1 : 0.4)
        }
        .frame(width: 72, height: 72)
    }
}

#Preview {
    VStack {
        MasteryRing(fraction: 0.42, masteredCount: 21, totalCount: 50)
        MasteryRing(fraction: 1, masteredCount: 30, totalCount: 30)
    }
    .padding()
    .background(Color.appBackground)
}
