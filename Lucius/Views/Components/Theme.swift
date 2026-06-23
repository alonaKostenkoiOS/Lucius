import SwiftUI

/// App-wide palette: soft lavender accent on a warm, light background.
/// The app always runs in light appearance (see `MainTabView`),
/// so these fixed colors are safe.
extension Color {
    static let lavender = Color(red: 0.55, green: 0.45, blue: 0.92)
    static let lavenderSoft = Color(red: 0.91, green: 0.88, blue: 0.99)
    static let deepPurple = Color(red: 0.33, green: 0.25, blue: 0.55)
    static let appBackground = Color(red: 0.96, green: 0.95, blue: 0.99)
    static let cardBackground = Color.white

    /// Answer semantics, shared by the review buttons and swipe gestures.
    static let answerForgot = Color.red
    static let answerAlmost = Color.orange
    static let answerKnow = Color.green
}

// MARK: - Design tokens

/// Spacing scale (multiples of 4) — use instead of scattered literals.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Corner radius scale; everything uses `.continuous` curves.
enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}

/// Named typography. Word headings use a serif for a "bookish" feel and
/// scale with Dynamic Type via `relativeTo:` so accessibility text sizes work.
extension Font {
    static let heroWord = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let largeWord = Font.system(.title, design: .serif).weight(.bold)
    static let cardWord = Font.system(.title2, design: .serif).weight(.bold)
    static let appTitle = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let sectionTitle = Font.title3.bold()
    static let cardLabel = Font.caption.weight(.semibold)
}

/// A single elevation token so cards read as one consistent surface.
struct Elevation {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let card = Elevation(color: Color.deepPurple.opacity(0.08), radius: 10, y: 4)
    static let lifted = Elevation(color: Color.deepPurple.opacity(0.16), radius: 22, y: 12)
}

extension View {
    func elevation(_ token: Elevation) -> some View {
        shadow(color: token.color, radius: token.radius, y: token.y)
    }
}

/// Soft lavender-to-light vertical wash used behind the main screens.
struct AppBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.lavenderSoft, .appBackground, .appBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension ReviewStatus {
    var badgeColor: Color {
        switch self {
        case .new: .blue
        case .learning: .orange
        case .familiar: .lavender
        case .mastered: .green
        }
    }
}

/// Shared card chrome: white surface, rounded corners, soft lavender shadow.
struct CardBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .elevation(.card)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackgroundModifier())
    }
}
