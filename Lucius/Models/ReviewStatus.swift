import Foundation

/// Learning progress of a word, advanced by review answers.
enum ReviewStatus: String, Codable, CaseIterable, Identifiable {
    case new
    case learning
    case familiar
    case mastered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .new: String(localized: "status.new")
        case .learning: String(localized: "status.learning")
        case .familiar: String(localized: "status.familiar")
        case .mastered: String(localized: "status.mastered")
        }
    }
}
