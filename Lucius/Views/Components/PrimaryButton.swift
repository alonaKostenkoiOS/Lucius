import SwiftUI

/// The app's main call-to-action button: bold label on a lavender capsule.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
            .background(isEnabled ? Color.lavender : Color.lavender.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md + 2, style: .continuous))
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Add word", systemImage: "plus") {}
        PrimaryButton(title: "Save word", isEnabled: false) {}
    }
    .padding()
}
