import SwiftUI

/// The "memory scene" block — the heart of the app's idea:
/// a word is remembered through a small visual story.
struct VisualSceneCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Visual scene", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lavender)
                .textCase(.uppercase)

            Text("\u{201C}\(text)\u{201D}")
                .font(.body.italic())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.lavenderSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    VisualSceneCard(text: "Imagine a dark rainy room with one candle on the table.")
        .padding()
        .background(Color.appBackground)
}
