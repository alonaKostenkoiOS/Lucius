import SwiftUI

struct ReviewModeSelectionView: View {
    @Binding var selection: Set<ReviewPracticeMode>
    let audioAvailable: Bool
    let onStart: () -> Void

    private var visibleModes: [ReviewPracticeMode] {
        ReviewPracticeMode.allCases.filter { audioAvailable || $0 != .listening }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Choose how to practice")
                        .font(.appTitle)
                        .foregroundStyle(Color.deepPurple)
                    Text("Select one or more modes. Lucius will mix multiple selections during the session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: Spacing.md) {
                    ForEach(visibleModes) { mode in
                        ReviewModeCard(
                            mode: mode,
                            isSelected: selection.contains(mode),
                            action: { toggle(mode) }
                        )
                    }
                }
            }
            .padding(Spacing.xl)
            .padding(.bottom, 90)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: "Start review",
                systemImage: "play.fill",
                isEnabled: !selection.isEmpty,
                action: onStart
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
        }
        .onChange(of: selection) { _, selection in
            ReviewModePreferences.save(selection)
        }
    }

    private func toggle(_ mode: ReviewPracticeMode) {
        Haptics.selection()
        if mode == .mixed {
            selection = selection == [.mixed] ? [] : [.mixed]
            return
        }

        selection.remove(.mixed)
        if selection.contains(mode) {
            selection.remove(mode)
        } else {
            selection.insert(mode)
        }
    }
}

struct ReviewModeCard: View {
    let mode: ReviewPracticeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.lg) {
                Image(systemName: mode.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.lavender)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? Color.lavender : Color.lavenderSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.lavender : Color.secondary.opacity(0.35))
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(isSelected ? Color.lavender : Color.clear, lineWidth: 2)
            }
            .elevation(.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.title). \(mode.description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    ReviewModeSelectionView(
        selection: .constant([.cloze, .typeWord]),
        audioAvailable: true,
        onStart: {}
    )
    .background(AppBackgroundGradient())
}
