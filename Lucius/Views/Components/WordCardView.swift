import SwiftUI

/// A compact word card for lists: word, translation, book and status badge.
struct WordCardView: View {
    let word: VocabularyWord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.word)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                StatusBadge(status: word.reviewStatus)
            }

            Text(word.translation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let bookTitle = word.bookTitle {
                Label(bookTitle, systemImage: "book")
                    .font(.caption)
                    .foregroundStyle(Color.lavender)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(word.word), \(word.translation)")
        .accessibilityValue(word.reviewStatus.displayName)
    }
}

/// A small colored capsule showing the word's learning status.
struct StatusBadge: View {
    let status: ReviewStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.badgeColor.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Status")
            .accessibilityValue(status.displayName)
    }
}

#Preview {
    VStack(spacing: 12) {
        WordCardView(word: VocabularyWord(
            word: "serendipity",
            translation: "счастливая случайность",
            bookTitle: "The Midnight Library",
            reviewStatus: .learning
        ))
        WordCardView(word: VocabularyWord(
            word: "flicker",
            translation: "мерцать",
            reviewStatus: .mastered
        ))
    }
    .padding()
    .background(Color.appBackground)
}
