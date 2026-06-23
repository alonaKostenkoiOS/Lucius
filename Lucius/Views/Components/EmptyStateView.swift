import SwiftUI

/// A friendly placeholder for empty lists and finished review sessions.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Color.lavender)
                .padding(20)
                .background(Color.lavenderSoft)
                .clipShape(Circle())

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "books.vertical",
        title: "No words yet",
        message: "Add your first word from a book you are reading."
    )
    .background(Color.appBackground)
}
