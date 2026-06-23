import SwiftUI

/// A self-contained confetti burst plus a "Mastered!" banner, shown when a
/// word reaches the mastered status. Pure SwiftUI — no third-party deps.
/// Drive it with the `isActive` binding; it auto-dismisses after the burst.
struct CelebrationView: View {
    @Binding var isActive: Bool

    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if isActive {
                ConfettiBurst()
                    .allowsHitTesting(false)
                    .transition(.opacity)

                masteredBanner
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .onChange(of: isActive) { _, active in
            dismissTask?.cancel()
            guard active else { return }
            // Clear after the animation so it can fire again next time.
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) { isActive = false }
            }
        }
        .onDisappear { dismissTask?.cancel() }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActive)
    }

    private var masteredBanner: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.answerKnow)
                .symbolEffect(.bounce, value: isActive)

            Text("Mastered!")
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(Color.deepPurple)
        }
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.xxxl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .elevation(.lifted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Word mastered")
    }
}

/// A one-shot shower of colored pieces falling and fading.
private struct ConfettiBurst: View {
    private let pieces: [ConfettiPiece] = (0..<70).map { ConfettiPiece(seed: $0) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece, size: proxy.size)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let xFraction: CGFloat
    let hue: Double
    let scale: CGFloat
    let delay: Double
    let drift: CGFloat
    let spin: Double
    let isCircle: Bool

    /// Deterministic pseudo-random layout from a seed — avoids `Math.random`
    /// style nondeterminism and keeps each piece distinct.
    init(seed: Int) {
        id = seed
        let r = { (salt: Int) -> Double in
            let v = sin(Double(seed * 928371 + salt * 12345)) * 43758.5453
            return v - v.rounded(.down)
        }
        xFraction = CGFloat(r(1))
        hue = r(2)
        scale = 0.6 + CGFloat(r(3)) * 0.9
        delay = r(4) * 0.25
        drift = CGFloat(r(5) - 0.5) * 140
        spin = (r(6) - 0.5) * 720
        isCircle = r(7) > 0.5
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let size: CGSize

    @State private var fall = false

    private var color: Color {
        // Keep it on-brand: lavenders, with warm accents mixed in.
        Color(hue: 0.6 + piece.hue * 0.25, saturation: 0.6, brightness: 0.95)
    }

    var body: some View {
        Group {
            if piece.isCircle {
                Circle().fill(color)
            } else {
                RoundedRectangle(cornerRadius: 1.5).fill(color)
            }
        }
        .frame(width: 9 * piece.scale, height: 13 * piece.scale)
        .position(
            x: size.width * piece.xFraction + (fall ? piece.drift : 0),
            y: fall ? size.height + 40 : -40
        )
        .rotationEffect(.degrees(fall ? piece.spin : 0))
        .opacity(fall ? 0 : 1)
        .onAppear {
            withAnimation(.easeIn(duration: 1.4).delay(piece.delay)) {
                fall = true
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var on = true
        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Button("Celebrate") { on = true }
                CelebrationView(isActive: $on)
            }
        }
    }
    return Demo()
}
